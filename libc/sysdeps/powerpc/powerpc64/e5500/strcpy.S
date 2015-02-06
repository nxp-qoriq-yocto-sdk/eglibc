/* Optimized strcpy implementation for PowerPC64.
   Copyright (C) 1997, 1999, 2000, 2002, 2003, 2011 Free Software Foundation, Inc.
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
	CALL_MCOUNT 2
#define rTMP	r0
#define rRTN	r3
#define rSRC	r4	/* pointer to previous word in src */
#define rDEST	r5	/* pointer to previous word in dest */
#define rWORD1	r6	/* word from src */
#define rFEFE	r7	/* constant 0xfefefefefefefeff (-0x0101010101010101) */
#define r7F7F	r8	/* constant 0x7f7f7f7f7f7f7f7f */
#define rNEG	r9	/* ~(word in s1 | 0x7f7f7f7f7f7f7f7f) */
#define rTMP1	r9
#define rWORD2	r10	/* word from src */
#define rWORD3	r11
#define rWORD4	r12

	dcbt	0,rSRC
	andi.	rTMP, rSRC, 0x07
	dcbtst	0,rRTN
	bne	L(src_unaligned)
	
	addi	rDEST, rRTN, -8	
	lis	rFEFE, -0x101
	lis	r7F7F, 0x7f7f
	ld	rWORD1, 0(rSRC)
	addi	rFEFE, rFEFE, -0x101
	addi	r7F7F, r7F7F, 0x7f7f
	sldi	rTMP, rFEFE, 32
	insrdi	r7F7F, r7F7F, 32, 0
	add	rFEFE, rFEFE, rTMP
	b	L(g2)

L(g0):	ldu	rWORD2, 8(rSRC)
	stdu	rWORD1, 8(rDEST)
	add	rTMP, rFEFE, rWORD2
	nor	rNEG, r7F7F, rWORD2
	and.	rTMP, rTMP, rNEG
	bne-	L(g1)
	ldu	rWORD1, 8(rSRC)
	stdu	rWORD2, 8(rDEST)
L(g2):	add	rTMP, rFEFE, rWORD1
	nor	rNEG, r7F7F, rWORD1
	and.	rTMP, rTMP, rNEG
	beq+	L(g0)

	mr	rWORD2, rWORD1
/* We've hit the end of the string.  Do the rest byte-by-byte.  */
L(g1):
	extrdi.	rTMP, rWORD2, 8, 0
	stb	rTMP, 8(rDEST)
	beqlr
	extrdi.	rTMP, rWORD2, 8, 8
	stb	rTMP, 9(rDEST)
	beqlr
	extrdi.	rTMP, rWORD2, 8, 16
	stb	rTMP, 10(rDEST)
	beqlr
	extrdi.	rTMP, rWORD2, 8, 24
	stb	rTMP, 11(rDEST)
	beqlr
	extrdi.	rTMP, rWORD2, 8, 32
	stb	rTMP, 12(rDEST)
	beqlr
	extrdi.	rTMP, rWORD2, 8, 40
	stb	rTMP, 13(rDEST)
	beqlr
	extrdi.	rTMP, rWORD2, 8, 48
	stb	rTMP, 14(rDEST)
	beqlr
	stb	rWORD2, 15(rDEST)
	blr

/* end of already aligned src */

L(src_got_aligned):
	lis	r7F7F, 0x7f7f
	lis	rFEFE, -0x101
	addi	rFEFE, rFEFE, -0x101
	ld	rWORD1, 0(rSRC)
	addi	r7F7F, r7F7F, 0x7f7f
	sldi	rTMP, rFEFE, 32
	insrdi	r7F7F, r7F7F, 32, 0
	add	rFEFE, rFEFE, rTMP
	add	rTMP, rFEFE, rWORD1
	nor	rNEG, r7F7F, rWORD1
	and.	rTMP, rTMP, rNEG
	bne	L(copy_rest_bytes_for_unaligned)
	ldu	rWORD2, 8(rSRC)
	std	rWORD1, 0(rDEST)
	add	rTMP, rFEFE, rWORD2
	nor	rNEG, r7F7F, rWORD2
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 8
	bne	L(move_register_10_for_unaligned)

L(loop_for_nonaligned):
	ld	rWORD1, 8(rSRC)
	std	rWORD2, 0(rDEST)
	add	rTMP, rFEFE, rWORD1
	nor	rNEG, r7F7F, rWORD1
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 8
	bne	L(copy_rest_bytes_for_unaligned)
	ldu	rWORD2, 16(rSRC)
	std	rWORD1, 0(rDEST)
	add	rTMP, rFEFE, rWORD2
	nor	rNEG, r7F7F, rWORD2
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 8
	bne	L(move_register_10_for_unaligned)
	ld	rWORD3, 8(rSRC)
	std	rWORD2, 0(rDEST)
	add	rTMP, rFEFE, rWORD3
	nor	rNEG, r7F7F, rWORD3
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 8
	bne	L(move_register_11)
	ldu	rWORD4, 16(rSRC)
	std	rWORD3, 0(rDEST)
	add	rTMP, rFEFE, rWORD4
	nor	rNEG, r7F7F, rWORD4
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 8
	bne	L(move_register_12)
	ldu	rWORD2, 8(rSRC)
	std	rWORD4, 0(rDEST)
	add	rTMP, rFEFE, rWORD2
	nor	rNEG, r7F7F, rWORD2
	and.	rTMP, rTMP, rNEG
	addi	rDEST, rDEST, 8
	beq	L(loop_for_nonaligned)

L(move_register_10_for_unaligned):
	 mr	rWORD1, rWORD2
L(copy_rest_bytes_for_unaligned):
	extrdi.	rTMP, rWORD1, 8, 0
	stb	rTMP, 0(rDEST)
	beqlr
	extrdi.	rTMP, rWORD1, 8, 8
	stb	rTMP, 1(rDEST)
	beqlr
	extrdi.	rTMP, rWORD1, 8, 16
	stb	rTMP, 2(rDEST)
	beqlr
	extrdi.	rTMP, rWORD1, 8, 24
	stb	rTMP, 3(rDEST)
	beqlr
	extrdi.	rTMP, rWORD1, 8, 32
	stb	rTMP, 4(rDEST)
	beqlr
	extrdi.	rTMP, rWORD1, 8, 40
	stb	rTMP, 5(rDEST)
	beqlr
	extrdi.	rTMP, rWORD1, 8, 48
	stb	rTMP, 6(rDEST)
	beqlr
	stb	rWORD1, 7(rDEST)
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
	cmpwi	rWORD1, 0
	stb	rWORD1, 0(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD2, 1(rSRC)
	cmpwi	rWORD2, 0
	stb	rWORD2, 1(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD3, 2(rSRC)
	cmpwi	rWORD3, 0
	stb	rWORD3, 2(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD2, 3(rSRC)
	cmpwi	rWORD2, 0
	stb	rWORD2, 3(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD1, 4(rSRC)
	cmpwi	rWORD1, 0
	stb	rWORD1, 4(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD3, 5(rSRC)
	cmpwi	rWORD3, 0
	stb	rWORD3, 5(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD3, 6(rSRC)
	cmpwi	rWORD3, 0
	stb	rWORD3, 6(rDEST)
	beq	L(endstrcpy)
	lbz	rWORD2, 7(rSRC)
	cmpwi	rWORD2, 0
	beq	L(endstrcpy1)
	li	rTMP1, 8
	sub	rTMP1, rTMP1, rTMP
	add	rSRC, rSRC, rTMP1
	add	rDEST, rDEST, rTMP1
	b	L(src_got_aligned)

L(endstrcpy1):
	stb	rWORD2, 7(rDEST)
L(endstrcpy):
	blr

END (strcpy)
libc_hidden_builtin_def (strcpy)
