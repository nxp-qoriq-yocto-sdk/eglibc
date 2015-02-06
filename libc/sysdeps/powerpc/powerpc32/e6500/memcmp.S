/* Optimized memcmp implementation for 32-bit e6500 PowerPC core.
   Copyright (C) 2010-2014 Free Software Foundation, Inc.
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

/* int [r3] memcmp (const char *s1 [r3],
		    const char *s2 [r4],
		    size_t size [r5])
	r3:source1 address, return equality
	r4:source2 address
	r5:byte count
	
	volatile fixed point registers usable:
	r0, r3-r12

	volatile floating point registers usable:
	f0-f13

	v0-v1 General use Volatile (Caller save)
	v2-v13 Parameters, general Volatile (Caller save)
	v14-v19 General Volatile (Caller save)

	CR0-CR1 Volatile condition code register fields
	CR5-CR7 Volatile condition code register fields
*/

#define rTMP	r0
#define rRTN	r3
#define rSTR1	r3	/* first string arg */
#define rSTR2	r4	/* second string arg */
#define rS2OFF	r7	/* second string arg + 16*/
#define rN	r5
#define rWORD1	r6	/* current word in s1 */
#define rWORD2	r7	/* current word in s2 */
#define rWORD3	r8	/* next word in s1 */
#define rWORD4	r9	/* next word in s2 */
#define rWORD5	r10	/* next word in s1 */
#define rWORD6	r11	/* next word in s2 */
#define rWORD7	r5	/* next word in s1 */
#define rWORD8	r12	/* next word in s2 */
#define rCOUNT	r11
#define rINDEX	r8

#define rVR0	v0
#define rVR1	v1
#define rVR2	v2
#define rVR3	v3
#define rVR4	v4
#define rVR5	v5
#define rVR6	v6
#define rVR7	v7
#define rVR8	v8
#define rVR9	v9
#define rVR10	v10
#define rVR11	v11
#define rVR14	v14
#define rVR15	v15
#define rVR16	v16
#define rVR17	v17
#define rVR18	v18
#define rVR19	v19

EALIGN (memcmp, 5, 0)
	cmplwi	rN, 0
	cmplwi	cr1, rN, 32
	beq	L(zero)
	ble	cr1, L(medium)

	neg	rTMP, rSTR1
	andi.	rCOUNT, rTMP, 15		/* check src1 alignment */
	bne	L(src1_nalign)
L(src1align16):
	rlwinm.	rTMP, r4, 0, 28, 31		/* check src2 alignment */
	srwi	rCOUNT, rN, 4			/* count = n / 16 */;
	cmplwi	cr5, rCOUNT, 0xFFF0		/* Check for large data compares */
	rlwinm	rN, rN, 0, 28, 31		/* rem = n % 16 */
	mtctr	rCOUNT
	li	rINDEX, 0
	bne	L(src2_nalign)
	bgt	cr5, L(large_align)

L(loop_align):
	lvx	rVR14, rSTR1, rINDEX
	lvx	rVR15, rSTR2, rINDEX
	addi	rINDEX, rINDEX, 16
	vcmpequb. rVR16, rVR14, rVR15
	vnor	rVR17, rVR16, rVR16
	bdnzt	4*cr6+lt, L(loop_align)
	cmplwi	cr1, rN, 0
	bge	cr6, L(Vwords_Differ)
	beq	cr1, L(zero)
	add	rSTR1, rSTR1, rINDEX
	add	rSTR2, rSTR2, rINDEX
L(small):
	srwi.	rCOUNT, rN, 3			/* count = rem / 8 */
	rlwinm	rN, rN, 0, 29, 31		/* n =   rem % 8 */
	beq	L(cmp_bytes)

	lwz	rWORD1, 0(rSTR1)
	lwz	rWORD2, 0(rSTR2)
	lwz	rWORD3, 4(rSTR1)
	lwz	rWORD4, 4(rSTR2)
	cmplw	cr0, rWORD1, rWORD2
	addi	rSTR1, rSTR1, 8
	cmplwi	cr5, rN, 0
	bne	cr0, L(bLcr0)
	cmplw	cr1, rWORD3, rWORD4
	addi	rSTR2, rSTR2, 8
	bne	cr1, L(bLcr1)
	beq	cr5, L(zero)

	.align	4
L(cmp_bytes):
	mtctr	rN
	lbz	rWORD1, 0(rSTR1)
	lbz	rWORD2, 0(rSTR2)
	bdz	L(b11)
	
	lbz	rWORD3, 1(rSTR1)
	lbz	rWORD4, 1(rSTR2)
	cmplw	cr0, rWORD1, rWORD2
	bdz	L(b12)

	lbz	rWORD5, 2(rSTR1)
	lbz	rWORD6, 2(rSTR2)
	cmplw	cr1, rWORD3, rWORD4
	bdz	L(b13)

	lbz	rWORD7, 3(rSTR1)
	lbz	rWORD8, 3(rSTR2)
	bne	cr0, L(bx11)
	cmplw	cr5, rWORD5, rWORD6
	bdz	L(b14)

	cmplw	cr6, rWORD7, rWORD8
	lbz	rWORD1, 4(rSTR1)
	lbz	rWORD2, 4(rSTR2)
	bne	cr1, L(bx12)
	bdz	L(b15)

	lbz	rWORD3, 5(rSTR1)
	lbz	rWORD4, 5(rSTR2)
	cmplw	cr0, rWORD1, rWORD2
	bne	cr5, L(bx13)
	bdz	L(b16)

	lbz	rWORD5, 6(rSTR1)
	lbz	rWORD6, 6(rSTR2)
	cmplw	cr1, rWORD3, rWORD4
	bne	cr6, L(bx14)

	bne	cr0, L(bx15)
	bne	cr1, L(bx16)
	sub	rRTN, rWORD5, rWORD6
	blr

L(b16):	
	bne	cr6, L(bx14)
	bne	cr0, L(bx15)
L(bx16):
	sub	rRTN, rWORD3, rWORD4
	blr

L(b15):	
	bne	cr5, L(bx13)
	bne	cr6, L(bx14)
L(bx15):
	sub	rRTN, rWORD1, rWORD2
	blr

L(b14):	
	bne	cr1, L(bx12)
	bne	cr5, L(bx13)
L(bx14):
	sub	rRTN, rWORD7, rWORD8
	blr

L(b13):
	bne	cr0, L(bx11)
	bne	cr1, L(bx12)
L(bx13):
	sub	rRTN, rWORD5, rWORD6
	blr

L(b12):
	bne	cr0, L(bx11)
L(bx12):
	sub	rRTN, rWORD3, rWORD4
	blr

L(b11):
L(bx11):
	sub	rRTN, rWORD1, rWORD2
	blr

	.align	4
L(medium):
	srwi.	rCOUNT, rN, 3			/* count = rem / 8 */
	rlwinm	rN, rN, 0, 29, 31		/* n =   rem % 8 */
	beq	L(cmp_bytes)
	mtctr	rCOUNT
	cmplwi	cr5, rN, 0

	lwz	rWORD1, 0(rSTR1)
	lwz	rWORD2, 0(rSTR2)
	lwz	rWORD3, 4(rSTR1)
	lwz	rWORD4, 4(rSTR2)
	cmplw	cr0, rWORD1, rWORD2
	addi	rSTR1, rSTR1, 8
	bne	cr0, L(bLcr0)
	cmplw	cr1, rWORD3, rWORD4
	addi	rSTR2, rSTR2, 8
	bne	cr1, L(bLcr1)
	bdz	L(check_small)

	lwz	rWORD1, 0(rSTR1)
	lwz	rWORD2, 0(rSTR2)
	lwz	rWORD3, 4(rSTR1)
	lwz	rWORD4, 4(rSTR2)
	cmplw	cr0, rWORD1, rWORD2
	addi	rSTR1, rSTR1, 8
	bne	cr0, L(bLcr0)
	cmplw	cr1, rWORD3, rWORD4
	addi	rSTR2, rSTR2, 8
	bne	cr1, L(bLcr1)
	bdz	L(check_small)

	lwz	rWORD1, 0(rSTR1)
	lwz	rWORD2, 0(rSTR2)
	lwz	rWORD3, 4(rSTR1)
	lwz	rWORD4, 4(rSTR2)
	cmplw	cr0, rWORD1, rWORD2
	addi	rSTR1, rSTR1, 8
	bne	cr0, L(bLcr0)
	cmplw	cr1, rWORD3, rWORD4
	addi	rSTR2, rSTR2, 8
	bne	cr1, L(bLcr1)
	bdz	L(check_small)

	lwz	rWORD1, 0(rSTR1)
	lwz	rWORD2, 0(rSTR2)
	lwz	rWORD3, 4(rSTR1)
	lwz	rWORD4, 4(rSTR2)
	cmplw	cr0, rWORD1, rWORD2
	addi	rSTR1, rSTR1, 8
	bne	cr0, L(bLcr0)
	cmplw	cr1, rWORD3, rWORD4
	addi	rSTR2, rSTR2, 8
	bne	cr1, L(bLcr1)
	li	rRTN, 0
	blr

	.align	4
L(check_small):
	beq	cr5, L(zero)
	b	L(cmp_bytes)

	.align	4
L(src1_nalign):
	lwz	rWORD1, 0(rSTR1)
	lwz	rWORD2, 0(rSTR2)
	lwz	rWORD3, 4(rSTR1)
	lwz	rWORD4, 4(rSTR2)
	subfc.	rWORD1, rWORD1, rWORD2
	bne	L(Words_Differ)
	subfc.	rWORD1, rWORD3, rWORD4
	bne	L(Words_Differ)
	lwz	rWORD1, 8(rSTR1)
	lwz	rWORD2, 8(rSTR2)
	lwz	rWORD3, 12(rSTR1)
	lwz	rWORD4, 12(rSTR2)
	subfc.	rWORD1, rWORD1, rWORD2
	bne	L(Words_Differ)
	subfc.	rWORD1, rWORD3, rWORD4
	bne	L(Words_Differ)
	subf	rN, rCOUNT, rN			/* n = n - count */
	cmplwi	cr7, rN, 32
	add	rSTR1, rSTR1, rCOUNT
	add	rSTR2, rSTR2, rCOUNT
	ble	cr7, L(medium)
	b	L(src1align16)

	.align 4
L(bLcr0):
	li	rRTN, 1
	bgtlr	cr0
	li	rRTN, -1
	blr

	.align 4
L(bLcr1):
	li	rRTN, 1
	bgtlr	cr1
	li	rRTN, -1
	blr

	.align	4
L(src2_nalign):
	addi	rS2OFF, rSTR2, 16
	bgt	cr5, L(large_nalign)
L(loop_nalign):
	lvx	rVR14, rSTR1, rINDEX
	lvsl	rVR3, 0, rSTR2			/* set permute control vector */
	lvx	rVR4, rS2OFF, rINDEX		/* load LSQ */
	lvx	rVR2, rSTR2, rINDEX		/* load MSQ */
	addi	rINDEX, rINDEX, 16
	vperm	rVR15, rVR2, rVR4, rVR3		/* align the data */
	vcmpequb. rVR16, rVR14, rVR15	
	vnor	rVR17, rVR16, rVR16
	bdnzt	4*cr6+lt, L(loop_nalign)
	cmplwi	cr1, rN, 0
	bge	cr6, L(Vwords_Differ)
	beq	cr1, L(zero)
	add	rSTR1, rSTR1, rINDEX
	add	rSTR2, rSTR2, rINDEX
	b	L(small)

	.align	4
L(large_nalign):
	lvxl	rVR14, rSTR1, rINDEX
	lvsl	rVR3, 0, rSTR2			/* set permute control vector */
	lvxl	rVR4, rS2OFF, rINDEX		/* load LSQ */
	lvxl	rVR2, rSTR2, rINDEX		/* load MSQ */
	addi	rINDEX, rINDEX, 16
	vperm	rVR15, rVR2, rVR4, rVR3		/* align the data */
	vcmpequb. rVR16, rVR14, rVR15	
	vnor	rVR17, rVR16, rVR16
	bdnzt	4*cr6+lt, L(large_nalign)
	cmplwi	cr1, rN, 0
	bge	cr6, L(Vwords_Differ)
	beq	cr1, L(zero)
	add	rSTR1, rSTR1, rINDEX
	add	rSTR2, rSTR2, rINDEX
	b	L(small)

	.align	4
L(large_align):
	lvxl	rVR14, rSTR1, rINDEX
	lvxl	rVR15, rSTR2, rINDEX
	addi	rINDEX, rINDEX, 16
	vcmpequb. rVR16, rVR14, rVR15
	vnor	rVR17, rVR16, rVR16
	bdnzt	4*cr6+lt, L(large_align)
	cmplwi	cr1, rN, 0
	bge	cr6, L(Vwords_Differ)
	beq	cr1, L(zero)
	add	rSTR1, rSTR1, rINDEX
	add	rSTR2, rSTR2, rINDEX
	b	L(small)

	.align	4
L(Words_Differ):
	subfe	rRTN, rWORD1, rWORD1
	nand	rRTN, rRTN, rRTN
	ori	rRTN, rRTN, 1
	blr

	.align	4
L(Vwords_Differ):
	vspltisb rVR18, 1
	vspltisb rVR1, 8
	vslb	rVR0, rVR1, rVR18
	vslb	rVR19, rVR0, rVR18
	vslb	rVR18, rVR19, rVR18
	vxor	rVR5, rVR5, rVR5

	vsum4ubs rVR2, rVR1, rVR18
	vsro	rVR9, rVR17, rVR19
	vsrw	rVR19, rVR17, rVR1
	vsro	rVR10, rVR17, rVR18
	vsrw	rVR18, rVR17, rVR0

	vsro	rVR0, rVR17, rVR2
	vor	rVR11, rVR9, rVR10

	vsro	rVR2, rVR18, rVR1
	vor	rVR11, rVR11, rVR0
	vcmpgtuw rVR11, rVR11, rVR5

	vor	rVR11, rVR11, rVR19
	vor	rVR11, rVR11, rVR18
	vor	rVR11, rVR11, rVR2
	vor	rVR15, rVR15, rVR11
	vor	rVR14, rVR14, rVR11
	li	rRTN, -1
	vcmpgtub. rVR8, rVR15, rVR14
	bnelr	cr6
	li	rRTN, 1
	blr

	.align 4 
L(zero):
	li	rRTN, 0
	blr

END (memcmp)
libc_hidden_builtin_def (memcmp)
weak_alias (memcmp, bcmp)
