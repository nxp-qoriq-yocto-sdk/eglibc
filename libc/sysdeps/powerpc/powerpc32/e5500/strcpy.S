/* Optimized strcpy implementation for e500mc 32-bit PowerPC.
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

/* See strlen.s for comments on how the end-of-string testing works.  */

/* char * [r3] strcpy (char *dest [r3], const char *src [r4])  */

EALIGN (strcpy, 4, 0)

#define rTMP	r0
#define rRTN	r3	/* incoming DEST arg preserved as result */
#define rSRC	r4	/* pointer to previous word in src */
#define rDEST	r5	/* pointer to previous word in dest */
#define rWORD1	r6	/* word from src */
#define rFEFE	r7	/* constant 0xfefefeff (-0x01010101) */
#define r7F7F	r8	/* constant 0x7f7f7f7f */
#define rNEG	r9	/* ~(word in s1 | 0x7f7f7f7f) */
#define rTMP1	r9
#define rWORD2	r10	/* word from src */
#define rWORD3	r11
#define rWORD4	r12

	andi.	rTMP, rSRC, 0x03
	bne	L(src_unaligned)

	addi	rDEST, rRTN, -4
	lis	rFEFE, -0x101
	lis	r7F7F, 0x7f7f
	lwz	rWORD2, 0(rSRC)
	addi	rFEFE, rFEFE, -0x101
	addi	r7F7F, r7F7F, 0x7f7f
	b	L(g2)

L(g0):	lwzu	rWORD1, 4(rSRC)
	stwu	rWORD2, 4(rDEST)
	add	rTMP, rFEFE, rWORD1
	nor	rNEG, r7F7F, rWORD1
	and.	rTMP, rTMP, rNEG
	bne	L(g1)
	lwzu	rWORD2, 4(rSRC)
	stwu	rWORD1, 4(rDEST)
L(g2):	add	rTMP, rFEFE, rWORD2
	nor	rNEG, r7F7F, rWORD2
	and.	rTMP, rTMP, rNEG
	beq	L(g0)

	mr	rWORD1, rWORD2
/* We've hit the end of the string.  Do the rest byte-by-byte.  */
L(g1):	rlwinm.	rTMP, rWORD1, 8, 24, 31
	stb	rTMP, 4(rDEST)
	beqlr
	rlwinm.	rTMP, rWORD1, 16, 24, 31
	stb	rTMP, 5(rDEST)
	beqlr
	rlwinm.	rTMP, rWORD1, 24, 24, 31
	stb	rTMP, 6(rDEST)
	beqlr
	stb	rWORD1, 7(rDEST)
	blr

/* end of already aligned src */

L(src_got_aligned):
	lis	r7F7F, 0x7f7f
	lwz	rWORD1, 0(rSRC)
	lis	rFEFE, -0x101
	addi	rFEFE, rFEFE, -0x101
	addi	r7F7F, r7F7F, 0x7f7f
	add	rTMP, rFEFE, rWORD1
	nor	rNEG, r7F7F, rWORD1
	and.	rTMP, rTMP, rNEG
	bne	L(copy_rest_bytes_for_unaligned)
	lwzu	rWORD2, 4(rSRC)
	stw	rWORD1, 0(rDEST)
	add	rTMP, rFEFE, rWORD2
	nor	rNEG, r7F7F, rWORD2
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 4 
	bne	L(move_register_10_for_unaligned)

L(loop_for_nonaligned):
	lwz	rWORD1, 4(rSRC)
	stw	rWORD2, 0(rDEST)
	add	rTMP, rFEFE, rWORD1
	nor	rNEG, r7F7F, rWORD1
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 4 
	bne	L(copy_rest_bytes_for_unaligned)
	lwzu	rWORD2, 8(rSRC)
	stw	rWORD1, 0(rDEST)
	add	rTMP, rFEFE, rWORD2
	nor	rNEG, r7F7F, rWORD2
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 4 
	bne	L(move_register_10_for_unaligned)
	lwz	rWORD3, 4(rSRC)
	stw	rWORD2, 0(rDEST)
	add	rTMP, rFEFE, rWORD3
	nor	rNEG, r7F7F, rWORD3
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 4 
	bne	L(move_register_11)
	lwzu	rWORD4, 8(rSRC)
	stw	rWORD3, 0(rDEST)
	add	rTMP, rFEFE, rWORD4
	nor	rNEG, r7F7F, rWORD4
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 4 
	bne	L(move_register_12)
	lwzu	rWORD2, 4(rSRC)
	stw	rWORD4, 0(rDEST)
	add	rTMP, rFEFE, rWORD2
	nor	rNEG, r7F7F, rWORD2
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 4 
	beq	L(loop_for_nonaligned)

L(move_register_10_for_unaligned):
	mr	rWORD1, rWORD2
L(copy_rest_bytes_for_unaligned):
	rlwinm.	rTMP, rWORD1, 8, 24, 31
	stb	rTMP, 0(rDEST)
	beqlr
	rlwinm.	rTMP, rWORD1, 16, 24, 31
	stb	rTMP, 1(rDEST)
	beqlr
	rlwinm.	rTMP, rWORD1, 24, 24, 31
	stb	rTMP, 2(rDEST)
	beqlr
	stb	rWORD1, 3(rDEST)
	blr

L(move_register_11):
	mr	rWORD1, rWORD3
	b	L(copy_rest_bytes_for_unaligned)
L(move_register_12):
	mr	rWORD1, rWORD4
	b	L(copy_rest_bytes_for_unaligned)

L(src_unaligned):
	lbz	rWORD1, 0(rSRC)
	addi	rDEST, rRTN, 0 
	cmpwi	rWORD1, 0x0
	stb	rWORD1, 0(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD2, 1(rSRC)
	cmpwi	rWORD2, 0x0
	stb	rWORD2, 1(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD3, 2(rSRC)
	cmpwi	rWORD3, 0x0
	stb	rWORD3, 2(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD2, 3(rSRC)
	cmpwi	rWORD2, 0x0
	beq	L(endstrcpy1)
	li	rTMP1, 4
	sub	rTMP1, rTMP1, rTMP 
	add	rSRC, rSRC, rTMP1
	add	rDEST, rDEST, rTMP1
	b	L(src_got_aligned)

L(endstrcpy1):
	stb	rWORD2, 3(rDEST)
L(endstrcpy):
	blr

END (strcpy)
libc_hidden_builtin_def (strcpy)
