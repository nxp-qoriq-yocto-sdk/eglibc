/* Optimized strchr implementation for PowerPC e500mc.
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

/* char * [r3] strchr (const char *s [r3] , int c [r4] )  */

ENTRY (strchr)

#define rTMP1	r0
#define rRTN	r3	/* outgoing result */
#define rSTR	r8	/* current word pointer */
#define rCHR	r4	/* byte we're looking for, spread over the whole word */
#define rWORD	r5	/* the current word */
#define rCLZB	rCHR	/* leading zero byte count */
#define rFEFE	r6	/* constant 0xfefefeff (-0x01010101) */
#define r7F7F	r7	/* constant 0x7f7f7f7f */
#define rTMP2	r9
#define rIGN	r10	/* number of bits we should ignore in the first word */
#define rMASK	r11	/* mask with the bits to ignore set to rTMP1 */
#define rTMP3	r12

	andi.	rTMP2, rRTN, 3
	clrrwi	rSTR, rRTN, 2
	rlwimi	rCHR, rCHR, 8, 16, 23
	rlwimi	rCHR, rCHR, 16, 0, 15
	lis	rFEFE, -0x101
	lis	r7F7F, 0x7f7f
	addi	rFEFE, rFEFE, -0x101
	addi	r7F7F, r7F7F, 0x7f7f
	beq	L(srcalign)
	lwz	rWORD, 0(rSTR)
	li	rMASK, -1
	rlwinm	rIGN, rRTN, 3, 27, 28
	srw	rMASK, rMASK, rIGN
	orc	rWORD, rWORD, rMASK
	add	rTMP1, rFEFE, rWORD
	xor	rTMP3, rCHR, rWORD
	nor	rTMP2, r7F7F, rWORD
	orc	rTMP3, rTMP3, rMASK
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
	b	L(loop)
L(srcalign):
/* Test the first (partial?) word.  */
	lwz	rWORD, 0(rSTR)
	add	rTMP1, rFEFE, rWORD
	xor	rTMP3, rCHR, rWORD
	nor	rTMP2, r7F7F, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)

/* The loop.  */
L(loop):
	lwzu	rWORD, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rWORD
/* Test for 0.	*/
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rIGN, rFEFE, rWORD 
/* Test for 0.	*/
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rIGN, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	lwzu	rWORD, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rWORD
/* Test for 0.	*/
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rIGN, rFEFE, rWORD
/* Test for 0.	*/
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rIGN, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	lwzu	rWORD, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rIGN, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rIGN, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	lwzu	rWORD, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rIGN, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rIGN, rTMP2
	add	rTMP1, rFEFE, rTMP3	
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	lwzu	rWORD, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rIGN, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rIGN, rTMP2
	add	rTMP1, rFEFE, rTMP3	
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	lwzu	rWORD, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rIGN, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rIGN, rTMP2
	add	rTMP1, rFEFE, rTMP3	
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	lwzu	rWORD, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rIGN, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rIGN, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	lwzu	rWORD, 4(rSTR)
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rTMP1, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rTMP1, rTMP2
	add	rTMP1, rFEFE, rTMP3
	bne	L(missed)
/* Start test for the bytes we're looking for.  */
	nor	rTMP2, r7F7F, rTMP3
	lwzu	rWORD, 4(rSTR)
	and.	rTMP1, rTMP1, rTMP2
	bne	L(foundit)
	add	rIGN, rFEFE, rWORD
/* Test for 0.  */
	nor	rTMP2, r7F7F, rWORD
	xor	rTMP3, rCHR, rWORD
	and.	rTMP1, rIGN, rTMP2
	add	rTMP1, rFEFE, rTMP3
	beq	L(loop)
/* There is a zero byte in the word, but may also be a matching byte (either
    before or after the zero byte).  In fact, we may be looking for a
    zero byte, in which case we return a match.  We guess that this hasn't
    happened, though.  */
L(missed):
	nor	rTMP2, r7F7F, rTMP3
	and.	rTMP1, rTMP1, rTMP2
	li	rRTN, 0
	beqlr

/* It did happen. Decide which one was first...
    I'm not sure if this is actually faster than a sequence of
   rotates, compares, and branches (we use it anyway because it's shorter).  */
	and	rFEFE, r7F7F, rWORD
	or	rMASK, r7F7F, rWORD
	and	rTMP1, r7F7F, rTMP3
	or	rIGN, r7F7F, rTMP3
	add	rFEFE, rFEFE, r7F7F
	add	rTMP1, rTMP1, r7F7F
	nor	rWORD, rMASK, rFEFE
	nor	rTMP2, rIGN, rTMP1
	cmplw	rWORD, rTMP2
	cntlzw	rCLZB, rTMP2
	bgtlr
	srwi	rCLZB, rCLZB, 3
	add	rRTN, rSTR, rCLZB
	blr

L(foundit):
	and	rTMP1, r7F7F, rTMP3
	or	rIGN, r7F7F, rTMP3
	add	rTMP1, rTMP1, r7F7F
	nor	rTMP2, rIGN, rTMP1
	cntlzw	rCLZB, rTMP2
	subi	rSTR, rSTR, 4
	srwi	rCLZB, rCLZB, 3
	add	rRTN, rSTR, rCLZB
	blr

END (strchr)

weak_alias (strchr,index)
libc_hidden_builtin_def (strchr)

