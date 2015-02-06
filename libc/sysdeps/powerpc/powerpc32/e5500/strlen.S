/* Optimized strlen implementation for PowerPC32/E5500 32-bit using cmpb insn.
   Copyright (C) 2010 Free Software Foundation, Inc.
   Contributed by Luis Machado <luisgpm@br.ibm.com>.
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA
   02110-1301 USA.  */

#include <sysdep.h>

/* int [r3] strlen (char *s [r3])  */
	
ENTRY (strlen)
	CALL_MCOUNT
	clrrwi	r4,r3,2	      /* Align the address to word boundary.  */
	rlwinm	r6,r3,3,27,28 /* Calculate padding.  */
	li	r0,0	      /* Word with null chars to use with cmpb.  */
	li	r5,-1	      /* MASK = 0xffffffffffffffff.  */
	lwz	r12,0(r4)     /* Load word from memory.  */
	srw	r5,r5,r6      /* MASK = MASK >> padding.  */
	orc	r9,r12,r5     /* Mask bits that are not part of the string.  */
	cmpb	r10,r9,r0     /* Check for null bytes in WORD1.  */
	cmpwi	cr7,r10,0     /* If r10 == 0, no null's have been found.  */
	bne	cr7,L(done)

	/* Are we now aligned to a fourword boundary?  If so, skip to
	   the main loop.  Otherwise, go through the alignment code.  */
	   
	mtcrf   0x01,r3
	bt	28,L(if_source_aligned_by_8_or_12)
	bt	29,L(if_source_aligned_by_4)

	/* Handle WORD2,WORD3,WORD4 as source is aligned by 0.  */
	lwzu	r12,4(r4)
	cmpb	r10,r12,r0
	cmpwi	cr7,r10,0
	bne	cr7,L(done)
	lwzu	r12,4(r4)
	cmpb	r10,r12,r0
	cmpwi	cr7,r10,0
	bne	cr7,L(done)
	lwzu	r12,4(r4)
	cmpb	r10,r12,r0
	cmpwi	cr7,r10,0
	bne	cr7,L(done)
	b	L(loop)	      /* We branch here (rather than falling through)
				 to skip the nops due to heavy alignment
				 of the loop below.  */

L(if_source_aligned_by_8_or_12):
	bt	29,L(loop)    /* if source address is aligned by 12 then only one word needs to be handled
				 to make source address as 16 byte align which we have already handled in
				 the begining, so jump directly to main loop. */
	lwzu	r12,4(r4)     /* else source is aligned by 8. */
	cmpb	r10,r12,r0
	cmpwi	cr7,r10,0
	bne	cr7,L(done)

L(loop):
	lwz	r8,4(r4)
	lwzu	r9,8(r4)
	lwz	r11,4(r4)
	lwzu	r12,8(r4)
	cmpb	r10,r8,r0
	cmpwi	cr7,r10,0
	bne	cr7,L(done1)
	cmpb	r10,r9,r0
	cmpwi	cr7,r10,0
	bne	cr7,L(done2)
	cmpb	r10,r11,r0
	cmpwi	cr7,r10,0
	bne	cr7,L(done3)
	cmpb	r10,r12,r0
	cmpwi	cr7,r10,0
	beq	cr7,L(loop)
	
	/* r10 has the output of the cmpb instruction, that is, it contains
		   0xff in the same position as the null byte in the original
	   word from the string.  Use that to calculate the length.  */
	
	cntlzw	r0,r10
	subf	r5,r3,r4
	srwi	r0,r0,3
	add	r3,r5,r0
	blr

L(done1):
	addi	r4,r4,-12     /* Adjust the address. */

L(done):
	cntlzw	r0,r10	      /* Count leading zeroes before the match.  */
	subf	r5,r3,r4
	srwi	r0,r0,3	      /* Convert leading zeroes to bytes.  */
	add	r3,r5,r0      /* Compute final length.  */
	blr

L(done2):
	addi	r4,r4,-8      /* Adjust the address. */
	b	L(done)

L(done3):
	addi	r4,r4,-4      /* Adjust the address. */
	b	L(done)

	/* if source address is aligned by 4 then total three words need to be handled
	      to make source address as 16 byte align in which we have already handled
	   one word in the begining, so now handle next two words then jump to main loop. */

L(if_source_aligned_by_4):
	lwzu	r12,4(r4)
	cmpb	r10,r12,r0
	cmpwi	cr7,r10,0
	bne	cr7,L(done)
	lwzu	r12,4(r4)
	cmpb	r10,r12,r0
	cmpwi	cr7,r10,0
	bne	cr7,L(done)
	b	L(loop)
	
END (strlen)
libc_hidden_builtin_def (strlen)
