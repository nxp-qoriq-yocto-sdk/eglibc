/* Optimized strrchr implementation for PowerPC e5500 [32-bit].
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
#define rTMP2	r5
#define rMASK	r6	/* calculate padding bits */
#define rTMP3	r7
#define rWORD	r12	/* the current word */
#define rWORD2	r9	/* following word */
#define rTMP4	r10	
#define rTMP5	r11

	dcbt	0, rRTN
	andi.	rTMP3, rRTN, 7	/* check for double word boundary */
	cmpwi	cr7, rCHR, 0
	li	rTMP1, 0
	/* Replicate byte to double word.  */
	rlwimi	rCHR, rCHR, 8, 16, 23
	rlwimi	rCHR,rCHR, 16, 0, 15
	beq	L(dwalign)
	subfic	rTMP3, rTMP3, 8
	cmplwi	cr6, rTMP3, 4
	clrrwi	rSTR, rRTN, 2	/* Align the address to word boundary.  */
	beq	cr6, L(word2)
	ble	cr6, L(LTword2)
	lwz	rWORD, 0(rSTR)	/* Load word from memory.  */
	rlwinm	rMASK, rRTN, 3, 27, 28	/* Calculate padding.  */
	/* Now rCHR has a word of c bytes and rTMP1 has
	a word of null bytes.  */
	li	 rRTN, 0
	beq	cr7, L(null_match)
	cmpb	rTMP4, rWORD, rCHR	/* Compare each byte against c byte.  */
	cmpb	rTMP5, rWORD, rTMP1	/* Compare each byte against null byte.  */
	/* Move the words left and right to discard the bits that are
	not part of the string and to bring them back as zeros.  */
	slw	rTMP4, rTMP4, rMASK
	slw	rTMP5, rTMP5, rMASK
	srw	rTMP4, rTMP4, rMASK
	srw	rTMP5, rTMP5, rMASK
	or	rTMP2, rTMP4, rTMP5	/* OR the results to speed things up.  */
	cmpwi	cr7, rTMP2, 0	/* If rTMP2 == 0, no c or null bytes
				 have been found.  */
	bne	cr7, L(done)
	/* Handle WORD2 of pair.  */
	lwzu	rWORD, 4(rSTR)
	cmpb	rTMP4, rWORD, rCHR
	cmpb	rTMP5, rWORD, rTMP1
	or	rTMP2, rTMP4, rTMP5
	cmpwi	cr7, rTMP2, 0
	bne	cr7, L(done)
	b	L(loop)	/* We branch here (rather than falling through)
				to skip the nops due to heavy alignment
				of the loop below.  */

L(LTword2):
	lwz	rWORD, 0(rSTR)	/* Load word from memory.  */
	rlwinm	rMASK,rRTN, 3, 27, 28	/* Calculate padding.  */
	/* Now rCHR has a word of c bytes and rTMP1 has
		a word of null bytes.  */
	li	rRTN,	0
	beq	cr7, L(null_LTword2)
	cmpb	rTMP4, rWORD, rCHR	/* Compare each byte against c byte.  */
	cmpb	rTMP5, rWORD, rTMP1	/* Compare each byte against null byte.  */
	/* Move the words left and right to discard the bits that are
	not part of the string and to bring them back as zeros.  */
	slw	rTMP4, rTMP4, rMASK
	slw	rTMP5, rTMP5, rMASK
	srw	rTMP4, rTMP4, rMASK
	srw	rTMP5, rTMP5, rMASK
	or	rTMP2, rTMP4, rTMP5	/* OR the results to speed things up.  */
	cmpwi	cr7, rTMP2, 0	/* If rTMP2 == 0, no c or null bytes
				 have been found.  */
	bne	cr7, L(done)
	b	L(loop)
	
L(word2):
	lwz	rWORD, 0(rSTR)
	li	rRTN,	0
	beq	cr7, L(null_word2)
	cmpb	rTMP4, rWORD, rCHR
	cmpb	rTMP5, rWORD, rTMP1
	or	rTMP2, rTMP4, rTMP5
	cmpwi	cr7, rTMP2, 0
	bne	cr7, L(done)
	b	L(loop)
L(dwalign):
	/* Load two words, compare and merge in a
	single register for speed.  This is an attempt
	to speed up the null-checking process for bigger strings.  */
	mr	rSTR, rRTN
	li	rRTN,	0
	lwz	rWORD, 0(rSTR)
	lwzu	rWORD2, 4(rSTR)
	beq	cr7, L(dwalignnull)
	cmpb	rTMP4, rWORD, rCHR
	cmpb	rTMP5, rWORD, rTMP1
	cmpb	rMASK, rWORD2, rCHR
	cmpb	rTMP3, rWORD2, rTMP1
	or	rWORD, rTMP4, rTMP5
	or	rWORD2, rMASK, rTMP3
	or	rTMP2, rWORD, rWORD2
	cmpwi	cr7, rTMP2, 0
	beq	cr7, L(loop)
	/* OK, one (or both) of the words contains a c/null byte.  Check
	the first word and decrement the address in case the first
	word really contains a c/null byte.  */
	cmpwi	cr6, rWORD, 0
	addi	rSTR, rSTR, -4
	bne	cr6, L(done)
	/* The c/null byte must be in the second word.  Adjust the address
	again and move the result of cmpb to rTMP4 so we can calculate the
	pointer.  */
	mr	rTMP4, rMASK
	mr	rTMP5, rTMP3
	addi	rSTR, rSTR, 4
	/* rTMP2 has the output of the cmpb instruction, that is, it contains
	0xff in the same position as the c/null byte in the original
	word from the string.  Use that to calculate the pointer.  */
	b	L(done)
L(loop):
	/* Load two words, compare and merge in a
	single register for speed.  This is an attempt
	to speed up the null-checking process for bigger strings.  */
	lwz	rWORD, 4(rSTR)
	lwzu	rWORD2, 8(rSTR)
	cmpb	rTMP4, rWORD, rCHR
	cmpb	rTMP5, rWORD, rTMP1
	cmpb	rMASK, rWORD2, rCHR
	cmpb	rTMP3, rWORD2, rTMP1
	or	rWORD, rTMP4, rTMP5
	or	rWORD2, rMASK, rTMP3
	or	rTMP2, rWORD, rWORD2
	cmpwi	cr7, rTMP2, 0
	beq	cr7, L(loop)
	/* OK, one (or both) of the words contains a c/null byte.  Check
	the first word and decrement the address in case the first
	word really contains a c/null byte.  */
	cmpwi	cr6, rWORD, 0
	addi	rSTR, rSTR, -4
	bne	cr6, L(done)
	/* The c/null byte must be in the second word.  Adjust the address
	again and move the result of cmpb to rTMP4 so we can calculate the
	pointer.  */
	mr	rTMP4, rMASK
	mr	rTMP5, rTMP3
	addi	rSTR, rSTR, 4
	/* rTMP2 has the output of the cmpb instruction, that is, it contains
	0xff in the same position as the c/null byte in the original
	word from the string.  Use that to calculate the pointer.  */
L(done):
	cntlzw	rTMP3, rTMP4	/* Count leading zeroes before c matches.  */
	cntlzw	rMASK, rTMP5	/* Count leading zeroes before null matches.  */
	cmplw	cr7, rTMP3, rMASK
	bgt	cr7, L(no_match)
	srwi	rMASK, rTMP3, 3	/* Convert leading zeroes to bytes.  */
	add	rRTN, rSTR, rMASK	/* Return address of the matching c byte
					or null in case c was not found.  */
	addi	rTMP4, rRTN, 1
	
L(loop_check):
	andi.	rTMP3, rTMP4, 7	/* check for double word boundary */
	beq	L(loop)
	subfic	rTMP3, rTMP3, 8
	cmpwi	cr6, rTMP3, 4
	clrrwi	rSTR, rTMP4, 2	/* Align the address to word boundary.  */
	lwz	rWORD, 0(rSTR)
	beq	cr6, L(word2_check)
	ble	cr6, L(LTword2_check)
	rlwinm	rMASK, rTMP4, 3, 27, 28	/* Calculate padding.  */
	/* Now rCHR has a word of c bytes and rTMP1 has
	a word of null bytes.  */
	cmpb	rTMP4, rWORD, rCHR	/* Compare each byte against c byte.  */
	cmpb	rTMP5, rWORD, rTMP1	/* Compare each byte against null byte.  */
	/* Move the words left and right to discard the bits that are
	not part of the string and to bring them back as zeros.  */
	slw	rTMP4, rTMP4, rMASK
	slw	rTMP5, rTMP5, rMASK
	srw	rTMP4, rTMP4, rMASK
	srw	rTMP5, rTMP5, rMASK
	or	rTMP2, rTMP4, rTMP5	/* OR the results to speed things up.  */
	cmpwi	cr7, rTMP2, 0	/* If rTMP2 == 0, no c or null bytes
				 have been found.  */
	bne	cr7, L(done)
	/* Handle WORD2 of pair.  */
	lwzu	rWORD, 4(rSTR)
	cmpb	rTMP4, rWORD, rCHR
	cmpb	rTMP5, rWORD, rTMP1
	or	rTMP2, rTMP4, rTMP5
	cmpwi	cr7, rTMP2, 0
	bne	cr7, L(done)
	b	L(loop)	/* We branch here (rather than falling through)
				to skip the nops due to heavy alignment
				of the loop below.  */

L(LTword2_check):
	rlwinm	rMASK,rTMP4, 3, 27, 28	/* Calculate padding.  */
	cmpb	rTMP4, rWORD, rCHR	/* Compare each byte against c byte.  */
	cmpb	rTMP5, rWORD, rTMP1	/* Compare each byte against null byte.  */
	/* Move the words left and right to discard the bits that are
	not part of the string and to bring them back as zeros.  */
	slw	rTMP4, rTMP4, rMASK
	slw	rTMP5, rTMP5, rMASK
	srw	rTMP4, rTMP4, rMASK
	srw	rTMP5, rTMP5, rMASK
	or	rTMP2, rTMP4, rTMP5	/* OR the results to speed things up.  */
	cmpwi	cr7, rTMP2, 0	/* If rTMP2 == 0, no c or null bytes
				 have been found.  */
	bne	cr7, L(done)
	b	L(loop)
	
L(word2_check):
	cmpb	rTMP4, rWORD, rCHR
	cmpb	rTMP5, rWORD, rTMP1
	or	rTMP2, rTMP4, rTMP5
	cmpwi	cr7, rTMP2, 0
	bne	cr7, L(done)
	b	L(loop)
	
L(no_match):
	blr
/* We are here because strrchr was called with a null byte.  */
L(null_match):
	/* rTMP1 has a word of null bytes.  */
	cmpb	rTMP2, rWORD, rTMP1	/* Compare each byte against null bytes.  */
	/* Move the words left and right to discard the bits that are
	not part of the string and to bring them back as zeros.  */
	slw	rTMP2, rTMP2, rMASK
	srw	rTMP2, rTMP2, rMASK
	cmpwi	cr7, rTMP2, 0	/* If rTMP4 == 0, no c or null bytes
				 have been found.  */
	bne	cr7, L(done_null)
	/* Handle WORD2 of pair.  */
	lwzu	rWORD, 4(rSTR)
	cmpb	rTMP2, rWORD, rTMP1
	cmpwi	cr7, rTMP2, 0
	bne	cr7, L(done_null)
	b	L(loop_null)	/* We branch here (rather than falling through)
				 to skip the nops due to heavy alignment
				 of the loop below.  */
L(null_LTword2):
/* rTMP1 has a word of null bytes.  */
	cmpb	rTMP2, rWORD, rTMP1	/* Compare each byte against null bytes.  */
	/* Move the words left and right to discard the bits that are
	not part of the string and to bring them back as zeros.  */
	slw	rTMP2, rTMP2, rMASK
	srw	rTMP2, rTMP2, rMASK
	cmpwi	cr7, rTMP2, 0	/* If rTMP4 == 0, no c or null bytes
				 have been found.  */
	bne	cr7, L(done_null)
	b	L(loop_null)
L(null_word2):
	/* Handle WORD2 of pair. */
	cmpb	rTMP2, rWORD, rTMP1
	cmpwi	cr7, rTMP2, 0
	bne	cr7, L(done_null)
	b	L(loop_null)	/* We branch here (rather than falling through)
				 to skip the nops due to heavy alignment
				 of the loop below.  */	
L(dwalignnull):
	/* Load two words, compare and merge in a
	single register for speed.  This is an attempt
	to speed up the null-checking process for bigger strings.  */
	cmpb	rTMP2, rWORD, rTMP1
	cmpb	rTMP4, rWORD2, rTMP1
	or	rMASK, rTMP2, rTMP4
	cmpwi	cr7, rMASK, 0
	beq	cr7, L(loop_null)
	/* OK, one (or both) of the words contains a null byte.  Check
	the first word and decrement the address in case the first
	word really contains a null byte.  */
	cmpwi	cr6, rTMP2, 0
	addi	rSTR, rSTR, -4
	bne	cr6, L(done_null)
	/* The null byte must be in the second word.  Adjust the address
	again and move the result of cmpb to rTMP4 so we can calculate the
	pointer.  */
	mr	rTMP2, rTMP4
	addi	rSTR, rSTR, 4
	/* rTMP2 has the output of the cmpb instruction, that is, it contains
	0xff in the same position as the null byte in the original
	word from the string.  Use that to calculate the pointer.  */
	b	L(done_null)
L(loop_null):
	/* Load two words, compare and merge in a
	single register for speed.  This is an attempt
	to speed up the null-checking process for bigger strings.  */
	lwz	rWORD, 4(rSTR)
	lwzu	rTMP5, 8(rSTR)
	cmpb	rTMP2, rWORD, rTMP1
	cmpb	rTMP4, rTMP5, rTMP1
	or	rMASK, rTMP2, rTMP4
	cmpwi	cr7, rMASK, 0
	beq	cr7, L(loop_null)
	/* OK, one (or both) of the words contains a null byte.  Check
	the first word and decrement the address in case the first
	word really contains a null byte.  */
	cmpwi	cr6, rTMP2, 0
	addi	rSTR, rSTR, -4
	bne	cr6, L(done_null)
	/* The null byte must be in the second word.  Adjust the address
	again and move the result of cmpb to rTMP4 so we can calculate the
	pointer.  */
	mr	rTMP2, rTMP4
	addi	rSTR, rSTR, 4
	/* rTMP2 has the output of the cmpb instruction, that is, it contains
	0xff in the same position as the null byte in the original
	word from the string.  Use that to calculate the pointer.  */
L(done_null):
	cntlzw	rTMP1, rTMP2	/* Count leading zeros before the match.  */
	srwi	rTMP1, rTMP1, 3	/* Convert leading zeros to bytes.  */
	add	rRTN, rSTR, rTMP1	/* Return address of the matching null byte.  */
	blr
END (strrchr)

weak_alias (strrchr,rindex)
libc_hidden_builtin_def (strrchr)
