;*****************************************************************************
;* x86-optimized functions for yadif filter
;*
;* Copyright (C) 2006 Michael Niedermayer <michaelni@gmx.at>
;* Copyright (c) 2013 Daniel Kang <daniel.d.kang@gmail.com>
;*
;* This file is part of FFmpeg.
;*
;* FFmpeg is free software; you can redistribute it and/or
;* modify it under the terms of the GNU Lesser General Public
;* License as published by the Free Software Foundation; either
;* version 2.1 of the License, or (at your option) any later version.
;*
;* FFmpeg is distributed in the hope that it will be useful,
;* but WITHOUT ANY WARRANTY; without even the implied warranty of
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;* Lesser General Public License for more details.
;*
;* You should have received a copy of the GNU Lesser General Public
;* License along with FFmpeg; if not, write to the Free Software
;* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
;******************************************************************************

%include "libavutil/x86/x86util.asm"

SECTION_RODATA

pb_1: times 16 db 1
pw_1: times 16 dw 1

SECTION .text

%macro CHECK 2
    movu      m2, [curq+t1+%1]
    movu      m3, [curq+t0+%2]
    mova      m4, m2
    mova      m5, m2
    pxor      m4, m3
    pavgb     m5, m3
    pand      m4, [pb_1]
    psubusb   m5, m4
    RSHIFT    m5, 1
    punpcklbw m5, m7
    mova      m4, m2
    psubusb   m2, m3
    psubusb   m3, m4
    pmaxub    m2, m3
    mova      m3, m2
    mova      m4, m2
    RSHIFT    m3, 1
    RSHIFT    m4, 2
    punpcklbw m2, m7
    punpcklbw m3, m7
    punpcklbw m4, m7
    paddw     m2, m3
    paddw     m2, m4
%endmacro

%macro CHECK1 0
    mova    m3, m0
    pcmpgtw m3, m2
    pminsw  m0, m2
    mova    m6, m3
    pand    m5, m3
    pandn   m3, m1
    por     m3, m5
    mova    m1, m3
%endmacro

%macro CHECK2 0
    paddw   m6, [pw_1]
    psllw   m6, 14
    paddsw  m2, m6
    mova    m3, m0
    pcmpgtw m3, m2
    pminsw  m0, m2
    pand    m5, m3
    pandn   m3, m1
    por     m3, m5
    mova    m1, m3
%endmacro

%macro LOAD 2
    movh      %1, %2
    punpcklbw %1, m7
%endmacro

%macro FILTER 3
%if cpuflag(avx2)
.loop%1:
    pxor            YMM15, YMM15
    vmovdqu         YMM0, [curq+t1]  ;c
    vmovdqu         YMM1, [curq+t0]  ;e

    vmovdqu         YMM2, [%2]
    vmovdqu         YMM3, [%3]
    vpsubusb        YMM4, YMM2, YMM3
    vpsubusb        YMM5, YMM3, YMM2
    vpmaxub         YMM4, YMM4, YMM5
    vpavgb          YMM5, YMM4, YMM15 ;tdiff0
    vpavgb          YMM4, YMM2, YMM3  ;d

    vmovdqu         YMM2, [prevq+t1]
    vmovdqu         YMM3, [prevq+t0]
    vmovdqu         YMM6, [nextq+t1]
    vmovdqu         YMM7, [nextq+t0]
    vpsubusb        YMM8, YMM2, YMM0
    vpsubusb        YMM9, YMM0, YMM2
    vpmaxub         YMM10, YMM8, YMM9
    vpsubusb        YMM8, YMM3, YMM1
    vpsubusb        YMM9, YMM1, YMM3
    vpmaxub         YMM8, YMM8, YMM9
    vpavgb          YMM8, YMM8, YMM10  ;tdiff1

    vpsubusb        YMM9, YMM6, YMM0
    vpsubusb        YMM10, YMM0, YMM6
    vpmaxub         YMM9, YMM9, YMM10
    vpsubusb        YMM6, YMM7, YMM1
    vpsubusb        YMM7, YMM1, YMM7
    vpmaxub         YMM6, YMM6, YMM7
    vpavgb          YMM6, YMM6, YMM9  ;tdiff2

    vpmaxub         YMM5, YMM5, YMM6
    vpmaxub         YMM14, YMM5, YMM8  ;diff
    cmp   DWORD r8m, 2
    jge .end%1
    vmovdqu         YMM2, [%2 + t1*2]
    vmovdqu         YMM3, [%2 + t0*2]
    vmovdqu         YMM5, [%3 + t1*2]
    vmovdqu         YMM6, [%3 + t0*2]
    vpavgb          YMM7, YMM2, YMM5
    vpavgb          YMM8, YMM3, YMM6
    vpunpcklbw      YMM2, YMM7, YMM15
    vpunpckhbw      YMM3, YMM7, YMM15  ;b
    vpunpcklbw      YMM5, YMM8, YMM15
    vpunpckhbw      YMM6, YMM8, YMM15  ;f
    vpunpcklbw      YMM7, YMM0, YMM15
    vpunpckhbw      YMM8, YMM0, YMM15  ;c
    vpsubw          YMM2, YMM2, YMM7
    vpsubw          YMM3, YMM3, YMM8  ;b-c
    vpunpcklbw      YMM9, YMM1, YMM15
    vpunpckhbw      YMM10, YMM1, YMM15  ;e
    vpsubw          YMM5, YMM5, YMM9
    vpsubw          YMM6, YMM6, YMM10  ;f-e
    vpminsw         YMM11, YMM2, YMM5
    vpmaxsw         YMM2, YMM2, YMM5
    vpminsw         YMM12, YMM3, YMM6  ;min 11,12
    vpmaxsw         YMM3, YMM3, YMM6  ;max 2,3
    vpunpcklbw      YMM5, YMM4, YMM15
    vpunpckhbw      YMM6, YMM4, YMM15  ;d
    vpsubw          YMM7, YMM5, YMM7
    vpsubw          YMM8, YMM6, YMM8  ;d-c
    vpsubw          YMM5, YMM5, YMM9
    vpsubw          YMM6, YMM6, YMM10  ;d-e
    vpminsw         YMM2, YMM7, YMM2
    vpmaxsw         YMM7, YMM7, YMM11
    vpminsw         YMM3, YMM8, YMM3
    vpmaxsw         YMM8, YMM8, YMM12
    vpminsw         YMM2, YMM2, YMM5
    vpmaxsw         YMM5, YMM7, YMM5
    vpminsw         YMM3, YMM3, YMM6
    vpmaxsw         YMM6, YMM8, YMM6

    vpsubw          YMM5, YMM15, YMM5
    vpsubw          YMM6, YMM15, YMM6
    vpackuswb       YMM2, YMM2, YMM3
    vpackuswb       YMM3, YMM5, YMM6
    vpmaxub         YMM2, YMM2, YMM3
    vpmaxub         YMM14, YMM14, YMM2  ;diff
.end%1:
    vpavgb          YMM5, YMM0, YMM1 ;spp

    vmovdqu         YMM12, [curq+t1 - 1]
    vmovdqu         YMM3, [curq+t0 - 1]
    vpsubusb        YMM6, YMM12, YMM3
    vpsubusb        YMM7, YMM3, YMM12
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM8, YMM6, YMM15
    vpunpckhbw      YMM9, YMM6, YMM15

    vpsubusb        YMM6, YMM0, YMM1
    vpsubusb        YMM7, YMM1, YMM0
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM8, YMM8, YMM7
    vpaddw          YMM9, YMM9, YMM6

    vmovdqu         YMM2, [curq+t1 + 1]
    vmovdqu         YMM13, [curq+t0 + 1]
    vpsubusb        YMM6, YMM2, YMM13
    vpsubusb        YMM7, YMM13, YMM2
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM8, YMM8, YMM7
    vpaddw          YMM9, YMM9, YMM6
    vpsubw          YMM8, YMM8, [pb_1]
    vpsubw          YMM9, YMM9, [pb_1]  ;plss

    vmovdqu         YMM2, [curq+t1 - 2]
    vpsubusb        YMM6, YMM1, YMM2
    vpsubusb        YMM7, YMM2, YMM1
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM10, YMM6, YMM15
    vpunpckhbw      YMM11, YMM6, YMM15

    vpsubusb        YMM6, YMM12, YMM13
    vpsubusb        YMM7, YMM13, YMM12
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM10, YMM10, YMM7
    vpaddw          YMM11, YMM11, YMM6

    vmovdqu         YMM3, [curq+t0 + 2]
    vpsubusb        YMM6, YMM0, YMM3
    vpsubusb        YMM7, YMM3, YMM0
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM10, YMM10, YMM7
    vpaddw          YMM11, YMM11, YMM6

    vpcmpgtw        YMM6, YMM8, YMM10
    vpcmpgtw        YMM7, YMM9, YMM11
    vpminuw         YMM8, YMM8, YMM10
    vpminuw         YMM9, YMM9, YMM11
    vpackuswb       YMM7, YMM6, YMM7
    vpavgb          YMM6, YMM12, YMM13
    vpand           YMM6, YMM6, YMM7
    vpandn          YMM5, YMM7, YMM5
    vpor            YMM5, YMM5, YMM6

    vmovdqu         YMM7, [curq+t1 - 3]
    vpsubusb        YMM6, YMM7, YMM13
    vpsubusb        YMM7, YMM13, YMM7
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM10, YMM6, YMM15
    vpunpckhbw      YMM11, YMM6, YMM15

    vpsubusb        YMM6, YMM2, YMM3
    vpsubusb        YMM7, YMM3, YMM2
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM10, YMM10, YMM7
    vpaddw          YMM11, YMM11, YMM6

    vmovdqu         YMM7, [curq+t0 + 3]
    vpsubusb        YMM6, YMM12, YMM7
    vpsubusb        YMM7, YMM7, YMM12
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM10, YMM10, YMM7
    vpaddw          YMM11, YMM11, YMM6

    vpcmpgtw        YMM6, YMM8, YMM10
    vpcmpgtw        YMM7, YMM9, YMM11
    vpminuw         YMM8, YMM8, YMM10
    vpminuw         YMM9, YMM9, YMM11
    vpackuswb       YMM7, YMM6, YMM7
    vpavgb          YMM6, YMM2, YMM3
    vpand           YMM6, YMM6, YMM7
    vpandn          YMM5, YMM7, YMM5
    vpor            YMM5, YMM5, YMM6

    vmovdqu         YMM3, [curq+t0 - 2]
    vpsubusb        YMM6, YMM0, YMM3
    vpsubusb        YMM7, YMM3, YMM0
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM10, YMM6, YMM15
    vpunpckhbw      YMM11, YMM6, YMM15

    vmovdqu         YMM12, [curq+t1 + 1]
    vmovdqu         YMM13, [curq+t0 - 1]
    vpsubusb        YMM6, YMM12, YMM13
    vpsubusb        YMM7, YMM13, YMM12
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM10, YMM10, YMM7
    vpaddw          YMM11, YMM11, YMM6

    vmovdqu         YMM2, [curq+t1 + 2]
    vpsubusb        YMM6, YMM1, YMM2
    vpsubusb        YMM7, YMM2, YMM1
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM10, YMM10, YMM7
    vpaddw          YMM11, YMM11, YMM6

    vpcmpgtw        YMM6, YMM8, YMM10
    vpcmpgtw        YMM7, YMM9, YMM11
    vpminuw         YMM8, YMM8, YMM10
    vpminuw         YMM9, YMM9, YMM11
    vpackuswb       YMM7, YMM6, YMM7
    vpavgb          YMM6, YMM12, YMM13
    vpand           YMM6, YMM6, YMM7
    vpandn          YMM5, YMM7, YMM5
    vpor            YMM5, YMM5, YMM6

    vmovdqu         YMM7, [curq+t0 - 3]
    vpsubusb        YMM6, YMM12, YMM7
    vpsubusb        YMM7, YMM7, YMM12
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM10, YMM6, YMM15
    vpunpckhbw      YMM11, YMM6, YMM15

    vpsubusb        YMM6, YMM2, YMM3
    vpsubusb        YMM7, YMM3, YMM2
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM10, YMM10, YMM7
    vpaddw          YMM11, YMM11, YMM6

    vmovdqu         YMM7, [curq+t1 + 3]
    vpsubusb        YMM6, YMM7, YMM13
    vpsubusb        YMM7, YMM13, YMM7
    vpmaxub         YMM6, YMM6, YMM7
    vpunpcklbw      YMM7, YMM6, YMM15
    vpunpckhbw      YMM6, YMM6, YMM15
    vpaddw          YMM10, YMM10, YMM7
    vpaddw          YMM11, YMM11, YMM6

    vpcmpgtw        YMM6, YMM8, YMM10
    vpcmpgtw        YMM7, YMM9, YMM11
    vpackuswb       YMM7, YMM6, YMM7
    vpavgb          YMM6, YMM2, YMM3
    vpand           YMM6, YMM6, YMM7
    vpandn          YMM5, YMM7, YMM5
    vpor            YMM5, YMM5, YMM6

    vpsubusb        YMM2, YMM4, YMM14
    vpaddusb        YMM3, YMM4, YMM14
    vpmaxub         YMM5, YMM5, YMM2
    vpminub         YMM0, YMM5, YMM3
    vmovdqu         [dstq], YMM0
    add        dstq, 32
    add       prevq, 32
    add        curq, 32
    add       nextq, 32
    sub   DWORD r4m, 32
    jg .loop%1
%else
.loop%1:
    pxor         m7, m7
    LOAD         m0, [curq+t1]
    LOAD         m1, [curq+t0]
    LOAD         m2, [%2]
    LOAD         m3, [%3]
    mova         m4, m3
    paddw        m3, m2
    psraw        m3, 1
    mova   [rsp+ 0], m0
    mova   [rsp+16], m3
    mova   [rsp+32], m1
    psubw        m2, m4
    ABS1         m2, m4
    LOAD         m3, [prevq+t1]
    LOAD         m4, [prevq+t0]
    psubw        m3, m0
    psubw        m4, m1
    ABS1         m3, m5
    ABS1         m4, m5
    paddw        m3, m4
    psrlw        m2, 1
    psrlw        m3, 1
    pmaxsw       m2, m3
    LOAD         m3, [nextq+t1]
    LOAD         m4, [nextq+t0]
    psubw        m3, m0
    psubw        m4, m1
    ABS1         m3, m5
    ABS1         m4, m5
    paddw        m3, m4
    psrlw        m3, 1
    pmaxsw       m2, m3
    mova   [rsp+48], m2

    paddw        m1, m0
    paddw        m0, m0
    psubw        m0, m1
    psrlw        m1, 1
    ABS1         m0, m2

    movu         m2, [curq+t1-1]
    movu         m3, [curq+t0-1]
    mova         m4, m2
    psubusb      m2, m3
    psubusb      m3, m4
    pmaxub       m2, m3
%if mmsize == 16
    mova         m3, m2
    psrldq       m3, 2
%else
    pshufw       m3, m2, q0021
%endif
    punpcklbw    m2, m7
    punpcklbw    m3, m7
    paddw        m0, m2
    paddw        m0, m3
    psubw        m0, [pw_1]

    CHECK -2, 0
    CHECK1
    CHECK -3, 1
    CHECK2
    CHECK 0, -2
    CHECK1
    CHECK 1, -3
    CHECK2

    mova         m6, [rsp+48]
    cmp   DWORD r8m, 2
    jge .end%1
    LOAD         m2, [%2+t1*2]
    LOAD         m4, [%3+t1*2]
    LOAD         m3, [%2+t0*2]
    LOAD         m5, [%3+t0*2]
    paddw        m2, m4
    paddw        m3, m5
    psrlw        m2, 1
    psrlw        m3, 1
    mova         m4, [rsp+ 0]
    mova         m5, [rsp+16]
    mova         m7, [rsp+32]
    psubw        m2, m4
    psubw        m3, m7
    mova         m0, m5
    psubw        m5, m4
    psubw        m0, m7
    mova         m4, m2
    pminsw       m2, m3
    pmaxsw       m3, m4
    pmaxsw       m2, m5
    pminsw       m3, m5
    pmaxsw       m2, m0
    pminsw       m3, m0
    pxor         m4, m4
    pmaxsw       m6, m3
    psubw        m4, m2
    pmaxsw       m6, m4

.end%1:
    mova         m2, [rsp+16]
    mova         m3, m2
    psubw        m2, m6
    paddw        m3, m6
    pmaxsw       m1, m2
    pminsw       m1, m3
    packuswb     m1, m1

    movh     [dstq], m1
    add        dstq, mmsize/2
    add       prevq, mmsize/2
    add        curq, mmsize/2
    add       nextq, mmsize/2
    sub   DWORD r4m, mmsize/2
    jg .loop%1
%endif
%endmacro

%macro YADIF 0
%if cpuflag(avx2)
cglobal yadif_filter_line, 4, 7, 16, 80, dst, prev, cur, next, w, prefs, \
                                        mrefs, parity, mode
%elseif ARCH_X86_32
cglobal yadif_filter_line, 4, 6, 8, 80, dst, prev, cur, next, w, prefs, \
                                        mrefs, parity, mode
%else
cglobal yadif_filter_line, 4, 7, 8, 80, dst, prev, cur, next, w, prefs, \
                                        mrefs, parity, mode
%endif
%if ARCH_X86_32
    mov            r4, r5mp
    mov            r5, r6mp
    DECLARE_REG_TMP 4,5
%else
    movsxd         r5, DWORD r5m
    movsxd         r6, DWORD r6m
    DECLARE_REG_TMP 5,6
%endif

    cmp DWORD paritym, 0
    je .parity0
    FILTER 1, prevq, curq
    jmp .ret

.parity0:
    FILTER 0, curq, nextq

.ret:
    RET
%endmacro

INIT_XMM ssse3
YADIF
INIT_XMM sse2
YADIF
%if ARCH_X86_32
INIT_MMX mmxext
YADIF
%endif
INIT_YMM avx2
YADIF
