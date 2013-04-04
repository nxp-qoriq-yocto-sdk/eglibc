/* Optimized memcpy implementation for e5500 64-bit PowerPC.
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

	cmpld cr0,r4,r3		// if source==destination, return.
	beqlr cr0

	cmpldi r5,8		// if number of bytes is less than 8 but greater than zero, copy byte-by-byte
	mr r6, r3
	blt Lcopy_bytes

	neg r0,r4		// temp = r0
	andi. r11,r0,7		// count = r11 [temp & 7]
	beq L1

	ld r12,0(r4)
	subf r5,r11,r5		// n = n - count
	add r4,r4,r11
	std r12,0(r6)	
	add r6,r6,r11

L1:
	cmpldi 7,r5,63
	ble 7,Lcopy_remaining
	srwi r11,r5,6		//count = n / CACHE_LINE_SIZE;
	rlwinm. r5,r5,0,26,31	//rem = n % CACHE_LINE_SIZE;
	mtctr r11		// move count
L5:
	ld  r0, 0(r4)		// 64-byte copy
	ld  r7, 8(r4)
	ld  r8,16(r4)
	ld  r9,24(r4)

	std r0, 0(r6)
	std r7, 8(r6)
	std r8,16(r6)
	std r9,24(r6)

	ld  r0,32(r4)
	ld  r7,40(r4)
	ld  r8,48(r4)
	ld  r9,56(r4)
	addi r4, r4, 64

	std r0,32(r6)
	std r7,40(r6)
	std r8,48(r6)
	std r9,56(r6)
	addi r6, r6, 64

	bdnz L5
	
Lcopy_remaining:
	srwi.  r11,r5,3		// count = rem / sizeof(unsigned long);
	rlwinm r5,r5,0,29,31	// n =   rem % sizeof(unsigned long);
	beq 0, Lcopy_bytes

	mtcrf   0x01,r11
	bf cr7*4+1,16f
	ld  r0, 0(r4)		// copy 32 bytes
	ld  r7, 8(r4)
	ld  r8,16(r4)
	ld  r9,24(r4)
	addi r4, r4, 32

	std r0,0(r6)
	std r7,8(r6)
	std r8,16(r6)
	std r9,24(r6)
	addi r6, r6, 32
16:
	bf cr7*4+2,8f
	ld  r7,0(r4)		// copy 16 bytes
	ld  r8,8(r4)
	addi r4, r4, 16
	std r7,0(r6)
	std r8,8(r6)
	addi r6, r6, 16
8:
	bf cr7*4+3, Lcopy_bytes
	ld  r7,0(r4)		// copy 8 bytes
	addi r4,r4,8
	std r7,0(r6)
	addi r6,r6,8

Lcopy_bytes:
	cmpldi cr1,r5,4
	cmpldi cr0,r5,1
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
	// 0 or 1 bytes
	mtocrf 0x1,r5		// nbytes == 0 ? return
	bflr 31
	lbz r0,0(r4)		// nbytes == 1
	stb r0,0(r6)
	blr	

END_GEN_TB (BP_SYM (memcpy),TB_TOCLESS)
libc_hidden_builtin_def (memcpy)
