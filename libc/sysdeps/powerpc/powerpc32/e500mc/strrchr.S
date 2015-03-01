/* Optimized strrchr implementation for PowerPC e500mc.
   Copyright (C) 1997, 1999, 2000, 2003 Free Software Foundation, Inc.
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
   License along with the GNU C Library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
   02111-1307 USA.  */

#include <sysdep.h>

/* See strlen.s for comments on how this works.  */

/* char * [r3] strrchr (const char *s [r3] , int c [r4] )  */

ENTRY (strrchr)

#define rTMP1	r0
#define rRTN	r3	/* outgoing result */
#define rSTR	r8	/* current word pointer */
#define rCHR	r4	/* byte we're looking for, spread over the whole word */
#define rWORD	r5	/* the current word */
#define rFEFE	r6	/* constant 0xfefefeff (-0x01010101) */
#define r7F7F	r7	/* constant 0x7f7f7f7f */
#define rTMP2	r9
#define rIGN	r10	/* number of bits we should ignore in the first word */
#define rMASK	r11	/* mask with the bits to ignore set to rTMP1 and to load preceding word */
#define rTMP3	r12

	andi.	rTMP2, rRTN, 3
	cmplwi	cr7, rCHR, 0
	rlwimi	rCHR, rCHR, 8, 16, 23
	rlwimi	rCHR, rCHR, 16, 0, 15
	lis	rFEFE, -0x101
	lis	r7F7F, 0x7f7f
	clrrwi	rSTR, rRTN, 2
	addi	rFEFE, rFEFE, -0x101
	addi	r7F7F, r7F7F, 0x7f7f
	lwz	rWORD, 0(rSTR)
	li	rIGN, -1
	beq	L(srcalign)
	rlwinm	rTMP1, rRTN, 3, 27, 28
	srw	rMASK, rIGN, rTMP1
	orc	rWORD, rWORD, rMASK
	li	rRTN, 0
	beq	cr7, L(null)
	add	rTMP1, rFEFE, rWORD
	nor	rTMP2, r7F7F, rWORD
	and.	rTMP1, rTMP1, rTMP2
	xor	rTMP3, rCHR, rWORD
	orc	rTMP3, rTMP3, rMASK
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
	b	L(loop)
L(srcalign):
	li	rRTN, 0
	beq	cr7, L(nullwordalign)
L(srcalign2):
	add	rTMP1, rFEFE, rWORD
	nor	rTMP2, r7F7F, rWORD
	and.	rTMP1, rTMP1, rTMP2
	xor	rTMP3, rCHR, rWORD
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
L(loop):
	lwzu	rMASK, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rMASK
/* Test for rTMP1.	*/
	nor	rTMP2, r7F7F, rMASK
	xor	rTMP3, rCHR, rMASK
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed1)
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit1)
	add	rTMP1, rFEFE, rWORD
/* Test for rTMP1.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
	lwzu	rMASK, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rMASK
/* Test for rTMP1.*/
	nor	rTMP2, r7F7F, rMASK
	xor	rTMP3, rCHR, rMASK
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed1)
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit1)
	add	rTMP1, rFEFE, rWORD
/* Test for rTMP1.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
	lwzu	rMASK, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rMASK
/* Test for rTMP1.  */
	nor	rTMP2, r7F7F, rMASK
	xor	rTMP3, rCHR, rMASK
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed1)
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit1)
	add	rTMP1, rFEFE, rWORD
/* Test for rTMP1.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
	lwzu	rMASK, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rMASK
/* Test for rTMP1.  */
	nor	rTMP2, r7F7F, rMASK
	xor	rTMP3, rCHR, rMASK
	and.	rTMP1, rTMP1, rTMP2
	add 	rTMP1, rFEFE, rTMP3
	bne	L(missed1)
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit1)
	add	rTMP1, rFEFE, rWORD
/* Test for rTMP1.  */
	nor	rTMP2, r7F7F, rWORD
	dcbt	rTMP1, rSTR
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	beq	L(loop)
L(missed):
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	beqlr
	and	rFEFE, r7F7F, rWORD
	or	rMASK, r7F7F, rWORD
	and	rTMP1, r7F7F, rTMP3
	or	rTMP2, r7F7F, rTMP3
	add	rFEFE, rFEFE, r7F7F
	add	rTMP1, rTMP1, r7F7F
	nor	rWORD, rMASK, rFEFE
	nor	rTMP2, rTMP2, rTMP1
	cmplw	rWORD, rTMP2
	bgtlr
	cntlzw	rWORD, rTMP2
	srwi	rWORD, rWORD, 3
	add	rRTN, rSTR, rWORD
	addi	rSTR, rRTN, 1
	andi.	rTMP2, rSTR, 3
	cmpwi	rFEFE, rTMP2, 2
	bgt	rFEFE, L(b3l)
	li	rTMP1, 24
	srw	rCHR, rCHR, rTMP1
	beq	rFEFE, L(b2)
	lbz	rWORD, 0(rSTR)
	cmpwi	rFEFE, rWORD, 0
	beq	rFEFE, L(b3l)
	lbzu	rTMP3, 1(rSTR)
	cmpw	r7F7F, rWORD, rCHR
	beq	r7F7F, L(ret1)
	cmpwi	rFEFE, rTMP3, 0
	beq	rFEFE, L(b3l)
	cmpw	r7F7F, rTMP3, rCHR
	beq	r7F7F, L(ret2)
	blr	
L(missed1):
	mr	rWORD,rMASK
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	beqlr
	and	rFEFE, r7F7F, rWORD
	or	rMASK, r7F7F, rWORD
	and	rTMP1, r7F7F, rTMP3
	or	rTMP2, r7F7F, rTMP3
	add	rFEFE, rFEFE, r7F7F
	add	rTMP1, rTMP1, r7F7F
	nor	rWORD, rMASK, rFEFE
	nor	rTMP2, rTMP2, rTMP1
	cmplw	rWORD, rTMP2
	bgtlr
	cntlzw	rWORD, rTMP2
	srwi	rWORD, rWORD, 3
	add	rRTN, rSTR, rWORD
	addi	rSTR, rRTN, 1
	andi.	rTMP2, rSTR, 3
	cmpwi	rFEFE, rTMP2, 2
	bgt	rFEFE, L(b3l)
	li	rTMP1, 24
	srw	rCHR, rCHR, rTMP1
	beq	rFEFE, L(b2)
	lbz	rWORD, 0(rSTR)
	cmpwi	rFEFE, rWORD, 0
	beq	rFEFE, L(b3l)
	lbzu	rTMP3, 1(rSTR)
	cmpw	r7F7F, rWORD, rCHR
	beq	r7F7F, L(ret1)
	cmpwi	rFEFE, rTMP3, 0
	beq	rFEFE, L(b3l)
	cmpw	r7F7F, rTMP3, rCHR
	beq	r7F7F, L(ret2)
	blr
L(ret2):
	mr	rRTN, rSTR
	blr
L(ret1):
	subi	rRTN, rSTR, 1
	blr
L(b2): 
	lbz	rWORD, 0(rSTR)
	cmpwi	rFEFE, rWORD, 0
	beq	rFEFE, L(b3l)
	cmpw	r7F7F, rWORD, rCHR
	beq	r7F7F, L(ret)
	blr
L(ret):
	mr	rRTN, rSTR
	blr
L(b3l): 
	blr
L(foundit):
	and	rTMP1, r7F7F, rTMP3
	or	rTMP2, r7F7F, rTMP3
	add	rTMP1, rTMP1, r7F7F
	nor	rTMP2, rTMP2, rTMP1
	cntlzw	rTMP3, rTMP2
	subi	rSTR, rSTR, 4
	srwi	rTMP3, rTMP3, 3
	add	rRTN, rSTR, rTMP3
	addi	rTMP1, rRTN, 1
L(Nextword):
	andi.	rTMP2, rTMP1, 3
	clrrwi	rSTR, rTMP1, 2
	bne	L(srcalign_make)
	mr	rWORD,rMASK
	b	L(srcalign2)
L(srcalign_make):
	rlwinm	rTMP1, rTMP1, 3, 27, 28
	slw	rWORD,rWORD, rTMP1
	srw	rWORD,rWORD, rTMP1
	srw	rMASK, rIGN, rTMP1
	orc	rWORD, rWORD, rMASK
	add	rTMP1, rFEFE, rWORD
	nor	rTMP2, r7F7F, rWORD
	and.	rTMP1, rTMP1, rTMP2
	xor	rTMP3, rCHR, rWORD
	orc	rTMP3, rTMP3, rMASK
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
	b	L(loop)
L(foundit1):
	and	rTMP1, r7F7F, rTMP3
	or	rTMP2, r7F7F, rTMP3
	add	rTMP1, rTMP1, r7F7F
	nor	rTMP2, rTMP2, rTMP1
	cntlzw	rTMP3, rTMP2
	subi	rSTR, rSTR, 4
	srwi	rTMP3, rTMP3, 3
	add	rRTN, rSTR, rTMP3
	addi	rTMP1, rRTN, 1
L(Nextword1):
	andi.	rTMP2, rTMP1, 3
	clrrwi	rSTR, rTMP1, 2
	beq 	L(srcalign2)
	mr	rWORD, rMASK
	rlwinm	rTMP1, rTMP1, rRTN, 27, 28
	slw	rWORD, rWORD, rTMP1
	srw	rWORD, rWORD, rTMP1
	srw	rMASK, rIGN, rTMP1
	orc	rWORD, rWORD, rMASK
	add	rTMP1, rFEFE, rWORD
	nor	rTMP2, r7F7F, rWORD
	and.	rTMP1, rTMP1, rTMP2
	xor	rTMP3, rCHR, rWORD
	orc	rTMP3, rTMP3, rMASK
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
	b	L(loop)
	
L(nullwordalign):
	add	rTMP1, rFEFE, rWORD
	nor	rTMP2, r7F7F, rWORD
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundnull)
	b	L(loopnull)
L(null):
	add	rTMP1, rFEFE, rWORD
	nor	rTMP2, r7F7F, rWORD
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundnull)
L(loopnull):
	lwzu	rWORD, 4(rSTR)
	add	rTMP1, rFEFE, rWORD
	nor	rTMP2, r7F7F, rWORD
	and.	rTMP1, rTMP1, rTMP2
	beq	L(loopnull)
L(foundnull):
	and	rTMP1, r7F7F, rWORD
	or	rIGN, r7F7F, rWORD
	add	rTMP1, rTMP1, r7F7F
	nor	rTMP2, rIGN, rTMP1
	cntlzw	rTMP3, rTMP2
	srwi	rTMP3, rTMP3, 3
	add	rRTN, rSTR, rTMP3
	blr
END (strrchr)

weak_alias (strrchr,rindex)
libc_hidden_builtin_def (strrchr)
