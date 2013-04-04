/* Optimized memcpy implementation for e5500 32-bit PowerPC.
   Copyright (C) 2003, 2006, 2011 Free Software Foundation, Inc.
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
#include <bp-sym.h>
#include <bp-asm.h>

/* __ptr_t [r3] memcpy (__ptr_t dst [r3], __ptr_t src [r4], size_t len [r5]);
   Returns 'dst'.

	 r3 = destination
	 r4 = source
	 r5 = byte count
	
	 volatile fixed point registers usable:
	 r0, r3-r12

	 volatile floating point registers usable:
	 f0-f13
*/	 

EALIGN (BP_SYM (memcpy), 5, 0)

	cmplw cr0,r4,r3		// if source==destination, return.
	beqlr cr0

	cmplwi r5,8		// if number of bytes is less than 8 (optimal value TBD), but greater than zero. copy byte-by-byte
	mr r6, r3
	blt Lcopy_bytes
	
	neg r0,r4		// temp = r0
	
	andi. r11,r0,3		// count = r11 [temp & 3]
	beq L1

	lwz r12,0(r4)
	subf r5,r11,r5		// n = n - count
	add r4,r4,r11
	stw r12,0(r6)	
	add r6,r6,r11
L1:
	cmplwi 7,r5,63
	ble 7,Lcopy_remaining

	andi. r10,r0,15		// rem = r10
	beq Lsrc_aligned

	subf. r10,r11,r10	// rem = rem - count;
	beq 0,Lsrc_aligned

	srwi r11,r10,2		// count = rem / sizeof(unsigned long);
	subf r5,r10,r5		// n = n - rem;
	mtctr r11
L2:
	lwz 0,0(r4)
	addi r4,r4,4
	stw 0,0(r6)
	addi r6,r6,4
	bdnz L2

Lsrc_aligned:	
	srwi. r11,r5,6		//count = n / CACHE_LINE_SIZE;
	beq 0, Lcopy_remaining
	rlwinm r5,r5,0,26,31	//rem = n % CACHE_LINE_SIZE;
	rlwinm. r0,r6,0,29,31
	mtctr r11		// move count
	bne 0, Lcopy_nalign	//

L5:
#ifndef _SOFT_FLOAT
	lfd  0, 0(r4)		// copy 64 bytes
	lfd  1, 8(r4)
	lfd  2,16(r4)
	lfd  3,24(r4)
	
	stfd 0, 0(r6)
	stfd 1, 8(r6)
	stfd 2,16(r6)
	stfd 3,24(r6)
	
	lfd  0,32(r4)
	lfd  1,40(r4)
	lfd  2,48(r4)
	lfd  3,56(r4)
	addi r4, r4, 64

	stfd 0,32(r6)
	stfd 1,40(r6)
	stfd 2,48(r6)
	stfd 3,56(r6)
	addi r6, r6, 64
#else
	lwz r0, 0(r4)
	lwz r7, 4(r4)
	lwz r8, 8(r4)
	lwz r9,12(r4)

	stw r0, 0(r6)
	stw r7, 4(r6)
	stw r8, 8(r6)
	stw r9,12(r6)

	lwz r0,16(r4)
	lwz r7,20(r4)
	lwz r8,24(r4)
	lwz r9,28(r4)

	stw r0,16(r6)
	stw r7,20(r6)
	stw r8,24(r6)
	stw r9,28(r6)

	lwz r0,32(r4)
	lwz r7,36(r4)
	lwz r8,40(r4)
	lwz r9,44(r4)

	stw r0,32(r6)
	stw r7,36(r6)
	stw r8,40(r6)
	stw r9,44(r6)

	lwz r0,48(r4)
	lwz r7,52(r4)
	lwz r8,56(r4)
	lwz r9,60(r4)
	addi r4, r4, 64

	stw r0,48(r6)
	stw r7,52(r6)
	stw r8,56(r6)
	stw r9,60(r6)
	addi r6, r6, 64
#endif
	bdnz L5

Lcopy_remaining:
	srwi.  r11,r5,3		// count = rem / sizeof(unsigned long);
	rlwinm r5,r5,0,29,31	// n =   rem % sizeof(unsigned long);
	beq 0, Lcopy_bytes

	mtcrf   0x01,r11
	bf cr7*4+1,16f

	lwz r0, 0(r4)		// copy 32 bytes
	lwz r7, 4(r4)
	lwz r8, 8(r4)
	lwz r9,12(r4)

	stw r0, 0(r6)	
	stw r7, 4(r6)
	stw r8, 8(r6)
	stw r9,12(r6)

	lwz r0,16(r4)
	lwz r7,20(r4)
	lwz r8,24(r4)
	lwz r9,28(r4)
	addi r4, r4, 32

	stw r0,16(r6)	
	stw r7,20(r6)
	stw r8,24(r6)
	stw r9,28(r6)
	addi r6, r6, 32

16:
	bf cr7*4+2,8f

	lwz r0, 0(r4)		// copy 16 bytes
	lwz r7, 4(r4)
	lwz r8, 8(r4)
	lwz r9,12(r4)
	addi r4, r4, 16

	stw r0, 0(r6)	
	stw r7, 4(r6)
	stw r8, 8(r6)
	stw r9,12(r6)
	addi r6, r6, 16
8:
	bf cr7*4+3, Lcopy_bytes
	lwz r0, 0(r4)		// copy 8 bytes
	lwz r7, 4(r4)
	addi r4, r4, 8
	
	stw r0, 0(r6)
	stw r7, 4(r6)
	addi r6, r6, 8
Lcopy_bytes:
	cmplwi cr1,r5,4
	cmplwi cr0,r5,1
	bgt cr1,1f		// nb > 4?  (5, 6, 7 bytes)
	ble cr0,2f		// nb <= 1? (0, 1 bytes)

	addi r0,r5,-2		// 2, 3, 4 bytes
	lhz r9,0(r4)
	lhzx r11,r4,r0
	sth r9,0(r6)
	sthx r11,r6,r0
	blr

1:
	addi r0,r5,-4		// 5, 6, 7 bytes
	lwz r9,0(r4)
	lwzx r11,r4,r0
	stw r9,0(r6)
	stwx r11,r6,r0
	blr

2:
	mtocrf 0x1,r5		// nbytes == 0 ? return
	bflr 31
	lbz r0,0(r4)		// nbytes == 1
	stb r0,0(r6)
	blr

Lcopy_nalign:
	lwz r0, 0(r4)		// copy 64 bytes; unaligned data
	lwz r7, 4(r4)
	lwz r8, 8(r4)
	lwz r9,12(r4)

	stw r0, 0(r6)
	stw r7, 4(r6)
	stw r8, 8(r6)
	stw r9,12(r6)

	lwz r0,16(r4)
	lwz r7,20(r4)
	lwz r8,24(r4)
	lwz r9,28(r4)

	stw r0,16(r6)
	stw r7,20(r6)
	stw r8,24(r6)
	stw r9,28(r6)

	lwz r0,32(r4)
	lwz r7,36(r4)
	lwz r8,40(r4)
	lwz r9,44(r4)

	stw r0,32(r6)
	stw r7,36(r6)
	stw r8,40(r6)
	stw r9,44(r6)

	lwz r0,48(r4)
	lwz r7,52(r4)
	lwz r8,56(r4)
	lwz r9,60(r4)
	addi r4, r4, 64

	stw r0,48(r6)
	stw r7,52(r6)
	stw r8,56(r6)
	stw r9,60(r6)
	addi r6, r6, 64

	bdnz Lcopy_nalign

	b Lcopy_remaining

	
END (BP_SYM (memcpy))
libc_hidden_builtin_def (memcpy)
