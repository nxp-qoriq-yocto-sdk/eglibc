/* Optimized memset implementation for e6500 32-bit PowerPC.
   Copyright (C) 1997-2014 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#include <sysdep.h>

/* __ptr_t [r3] memset (__ptr_t s [r3], int c [r4], size_t n [r5]));
   Returns 's'.
 */

#define rTMP	r0
#define rRTN	r3	/* initial value of 1st argument */
#define rMEMP0	r3	/* original value of 1st arg */
#define rCHR	r4	/* char to set in each byte */
#define rLEN	r5	/* length of region to set */
#define rMEMP	r6	/* address at which we are storing */
#define rALIGN	r7	/* number of bytes we are setting now (when aligning) */

#define rPOS16	r7	/* constant +16 */
#define rPOS32	r8	/* constant +32 */
#define rPOS48	r9	/* constant +48 */

#define rGOT	r9	/* Address of the Global Offset Table. */
#define rCLS	r9	/* Cache line size obtained from static. */


#define rCTR2	r7
#define rCTR1	r11
#define rTMP1	r12

#define vCHR	v14	/* char to set in each byte */
#define vTMP1	v15
#define vTMP2	v16

	.section	".text"
EALIGN (memset, 5, 1)
	cmplwi	cr1, rLEN, 4
	cmplwi	cr5, rLEN, 32
	mr	rMEMP, rMEMP0
	ble	cr1, L(small)
	rlwimi	rCHR, rCHR, 8, 16, 23
	rlwimi	rCHR, rCHR, 16, 0, 15
	blt	cr5, L(medium)

	neg	rTMP, rMEMP	
	andi.	rTMP, rTMP, 15	
	bne	L(nalign16)

L(align16):
	cmplwi	7, rLEN, 63
	rlwinm.	rTMP1, rCHR, 28, 28, 3
	li	rPOS16, 16
	ble	7, L(copy_remaining)
	beq	L(check_cache_line_size)

L(vec_nz):
	srwi	rCTR1, rLEN, 6		/* count = n / CACHE_LINE_SIZE */;
	rlwinm	rLEN, rLEN, 0, 26, 31	/* rem = n % CACHE_LINE_SIZE; */
	vxor	vCHR, vCHR, vCHR
	mtctr	rCTR1			/* move count */
	lvsl	vCHR, 0, rTMP1		/* LSU Move upper nibble to byte 0 of VR */
	vspltisb	vTMP1, 4	/* VPU Splat 0x4 to every byte */
	lvsl	vTMP2, 0, rCHR		/* LSU Move lower nibble to byte 0 of VR */
	vslb	vCHR, vCHR, vTMP1	/* VIU Move upper nibble to VR[0:3] */
	vor	vCHR, vCHR, vTMP2	/* VIU Form FILL byte in VR[0:7] */
	vspltb	vCHR, vCHR, 0		/* VPU Splat the fill byte to all bytes */
	li	rPOS32, 32
	li	rPOS48, 48

L(vnz_loop):
	stvx	vCHR, 0, rMEMP
	stvx	vCHR, rPOS16, rMEMP
	stvx	vCHR, rPOS32, rMEMP
	stvx	vCHR, rPOS48, rMEMP
	addi	rMEMP, rMEMP, 64
	bdnz	L(vnz_loop)

L(copy_remaining):
	srwi.	rCTR1, rLEN, 3		/* count = rem / sizeof(unsigned long); */
	rlwinm	rLEN, rLEN, 0, 29, 31	/* n =   rem % sizeof(unsigned long); */
	cmplwi	cr1, rLEN, 1
	bne	0, L(copy_words)

L(copy_bytes):
	bltlr	cr1
	cmplwi	cr0, rLEN, 4
	beq	cr1, 2f			/* nb <= 1? (0, 1 bytes) */
	bgt	cr0, 1f			/* nb > 4?  (5, 6, 7 bytes) */

	addi	rTMP, rLEN, -2		/* 2, 3, 4 bytes */
	sth	rCHR, 0(rMEMP)
	sthx	rCHR, rMEMP, rTMP
	blr

1:
	addi	rTMP, rLEN, -4		/* 5, 6, 7 bytes */
	stw	rCHR, 0(rMEMP)
	stwx	rCHR, rMEMP, rTMP
	blr

2:	stb	rCHR, 0(rMEMP)
	blr

L(copy_words):
	mtcrf	0x01, rCTR1

	bf	cr7*4+1, 16f
	stw	rCHR, 0(rMEMP)
	stw	rCHR, 4(rMEMP)
	stw	rCHR, 8(rMEMP)
	stw	rCHR, 12(rMEMP)
	stw	rCHR, 16(rMEMP)
	stw	rCHR, 20(rMEMP)
	stw	rCHR, 24(rMEMP)
	stw	rCHR, 28(rMEMP)
	addi	rMEMP, rMEMP, 32

16:
	bf	cr7*4+2, 8f
	stw	rCHR, 0(rMEMP)
	stw	rCHR, 4(rMEMP)
	stw	rCHR, 8(rMEMP)
	stw	rCHR, 12(rMEMP)
	addi	rMEMP, rMEMP, 16

8:
	bf	cr7*4+3, L(copy_bytes)
	stw	rCHR, 0(rMEMP)
	stw	rCHR, 4(rMEMP)
	bltlr	cr1
	addi	rMEMP, rMEMP, 8
	b L(copy_bytes)

	.align	5	
L(check_cache_line_size):
#ifdef SHARED
	mflr rTMP
/* Establishes GOT addressability so we can load __cache_line_size
   from static. This value was set from the aux vector during startup.  */
	SETUP_GOT_ACCESS(rGOT,got_label_1)
	addis	rGOT, rGOT, __cache_line_size-got_label_1@ha
	lwz	rCLS, __cache_line_size-got_label_1@l(rGOT)
	mtlr	rTMP
#else
/* Load __cache_line_size from static. This value was set from the
   aux vector during startup.  */
	lis	rCLS,__cache_line_size@ha
	lwz	rCLS,__cache_line_size@l(rCLS)
#endif

	cmplwi	5, rCLS, 64
	neg	rTMP, rMEMP		/* temp = rTMP */
	bne	5, L(vec_nz)

	andi.	rTMP, rTMP, 63		/* count = r11 [temp & 63] */
	bne	L(nalign64)
	
L(align64):
	srwi	rCTR1, rLEN, 6		/* count = n / CACHE_LINE_SIZE */;
	cmplwi	7, rCTR1, 32767
	rlwinm	rLEN, rLEN, 0, 26, 31	/* rem = n % CACHE_LINE_SIZE; */	
	mtctr	rCTR1			/* move count */
	bgt	7, L(vec_zbig)

L(vz_loop):
	dcbzl	0, rMEMP
	addi	rMEMP, rMEMP, 64
	bdnz	L(vz_loop)
	b	L(copy_remaining)

L(vec_zbig):
	addi	rCTR2, rCTR1, -32767
	mtctr	rCTR2

L(vz_big_loop):
	dcbzl	0, rMEMP
	dcbf	0, rMEMP
	addi	rMEMP, rMEMP, 64
	bdnz	L(vz_big_loop)
	li	rCTR1, 32767
	mtctr	rCTR1
	b	L(vz_loop)

L(nalign64):	
	vxor	vCHR, vCHR, vCHR
	subf	rLEN, rTMP, rLEN	/* n = n - count */
	li	rPOS48, 48
	li	rPOS32, 32
	stvx	vCHR, 0, rMEMP
	stvx	vCHR, rPOS16, rMEMP
	cmplwi	7, rLEN, 64
	stvx	vCHR, rPOS32, rMEMP
	stvx	vCHR, rPOS48, rMEMP
	add	rMEMP, rMEMP, rTMP
	blt	7, L(copy_remaining)
	b	L(align64)

L(nalign16):
	stw	rCHR, 0(rMEMP)
	stw	rCHR, 4(rMEMP)
	subf	rLEN, rTMP, rLEN
	stw	rCHR, 8(rMEMP)
	stw	rCHR, 12(rMEMP)
	add	rMEMP, rMEMP, rTMP
	b	L(align16)

	.align	5
/* Memset of 0-4 bytes. Taken from GLIBC default memset */
L(small):
	cmplwi	cr5, rLEN, 1
	cmplwi	cr1, rLEN, 3
	bltlr	cr5
	stb	rCHR, 0(rMEMP)
	beqlr	cr5
	nop
	stb	rCHR, 1(rMEMP)
	bltlr	cr1
	stb	rCHR, 2(rMEMP)
	beqlr	cr1
	nop
	stb	rCHR, 3(rMEMP)
	blr

/* Memset of 0-31 bytes. Taken from GLIBC default memset */
	.align	5
L(medium):
	mtcrf	0x01, rLEN
	cmplwi	cr1, rLEN, 16
	add	rMEMP, rMEMP, rLEN
	bt	31, L(medium_31t)
	bt	30, L(medium_30t)
L(medium_30f):
	bt	29, L(medium_29t)
L(medium_29f):
	bge	cr1, L(medium_27t)
	bflr	28
	stw	rCHR, -4(rMEMP)
	stw	rCHR, -8(rMEMP)
	blr

L(medium_31t):
	stbu	rCHR, -1(rMEMP)
	bf	30, L(medium_30f)
L(medium_30t):
	sthu	rCHR, -2(rMEMP)
	bf	29, L(medium_29f)
L(medium_29t):
	stwu	rCHR, -4(rMEMP)
	blt	cr1, L(medium_27f)
L(medium_27t):
	stw	rCHR, -4(rMEMP)
	stw	rCHR, -8(rMEMP)
	stw	rCHR, -12(rMEMP)
	stwu	rCHR, -16(rMEMP)
L(medium_27f):
	bflr	28
L(medium_28t):
	stw	rCHR, -4(rMEMP)
	stw	rCHR, -8(rMEMP)
	blr

END (memset)
libc_hidden_builtin_def (memset)
