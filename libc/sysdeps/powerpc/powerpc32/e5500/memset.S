/* Optimized memset implementation for PowerPC/e5500 32 bit target
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

/* __ptr_t [r3] memset (__ptr_t s [r3], int c [r4], size_t n [r5]));
   Returns 's'.

   The memset is done in four sizes: byte (8 bits), word (32 bits),
   32-byte blocks (256 bits) and __cache_line_size (512 bits).
   There is a special case for setting whole cache lines to 0, which
   takes advantage of the dcbzl instruction.  */

#include <sysdep.h>

	.section	.text
EALIGN (memset, 6, 0)

#define rTMP	r0
#define rCNT	r0
#define rMEMP0	r3	/* original value of 1st arg */
#define rCHR	r4	/* char to set in each byte */
#define rLEN	r5	/* length of region to set */
#define rMEMP	r6	/* address at which we are storing */
#define rALIGN	r7	/* number of bytes we are setting now (when aligning) */
#define rTMP2	r8
#define rMEMP2	r9
#define rPOS64	r10	/* constant +64 for clearing with dcbzl */
#define rPOS128	r11	/* constant +128 for clearing with dcbzl */
#define rNEG128	r11	/* constant -128 for clearing with dcbzl */
#define rPOS192	r12	/* constant +192 for clearing with dcbzl */
#define rCLS	r11
#define rGOT	r12


/* For sizes < 8 bytes, do it in a combination of word/half word/byte stores */
	cmplwi	cr1, rLEN, 7
	mtcrf	0x01, rLEN
	add	rMEMP2, rMEMP0, rLEN
	ble	cr1, L(upTo7Bytes)
/* For sizes < 32 bytes, do it in a combination of double word, word, half word
   and byte stores */
	cmplwi	cr5, rLEN, 31
	rlwimi	rCHR, rCHR, 8, 16, 23	/* Replicate byte to halfword */
	rlwimi	rCHR, rCHR, 16, 0, 15	/* Replicate half word to word */
	ble	cr5, L(nAupTo31Bytes)
/* Get the destination address double word aligned */
	mr	rMEMP, rMEMP0
	andi.	rALIGN, rMEMP, 7
	insrdi	rCHR, rCHR, 32, 0	/* Replicate word to double word */
	beq	L(DwAligned)
	andi.	rTMP, rMEMP, 4
	subfic	rALIGN, rALIGN, 8
/* By now, we know that there are at least 7 bytes to memset and the destination
   address is not double word aligned. Do not bother about non-alignment and do
   a one word store at once and word align the destination address. The penalty for
   non-aligned store is less compared to the if-else checks and related code */
	stw	rCHR, 0(rMEMP0)
	sub	rLEN, rLEN, rALIGN
	add	rMEMP, rMEMP, rALIGN
	bne	L(DwAligned)
	stw	rCHR, -4(rMEMP)
L(DwAligned):
/* Now the destination address is double word aligned. For sizes 256 > size >= 32,
   do the memset in a combination of 64 bytes/32 bytes. For this size range, the
   overhead in getting the destination address cache aligned is more compared to
   the advantage of setting cache line size (64) bytes per iteration. But for
   the memset of zero value case, since we use 'dcbzl' instruction to clear entire
   cache line, we can set cache lines for sizes >= 128 bytes */
	cmplwi	cr5, rLEN, 128
	cmplwi	cr1, rCHR, 0
	blt	cr5, L(Upto255Bytes)
	srwi.	rTMP, rLEN, 8
	beq	cr1, L(SetCacheLines)
	bne	L(SetCacheLines)
L(Upto255Bytes):
	srwi.	rTMP2, rLEN, 6
	mtcrf	0x02, rLEN
	beq	L(DwA8WordSet)
	mtctr	rTMP2
/* Store 64 bytes at one go */
L(DwA16WordSet):
	std	rCHR, 0(rMEMP)
	std	rCHR, 8(rMEMP)
	std	rCHR, 16(rMEMP)
	std	rCHR, 24(rMEMP)
	std	rCHR, 32(rMEMP)
	std	rCHR, 40(rMEMP)
	std	rCHR, 48(rMEMP)
	std	rCHR, 56(rMEMP)
	addi	rMEMP, rMEMP, 64
	bdnz	L(DwA16WordSet)
/* Store 32 bytes at one go */
L(DwA8WordSet):
	rlwinm.	rLEN, rLEN, 0, 27, 31
	bf	cr6*4+2, L(Upto31Bytes)
	std	rCHR, 0(rMEMP)
	std	rCHR, 8(rMEMP)
	std	rCHR, 16(rMEMP)
	std	rCHR, 24(rMEMP)
	addi	rMEMP, rMEMP, 32
	beqlr
	b	L(Upto31Bytes)

L(SetCacheLines):
	neg	rTMP2, rMEMP
	andi.	rALIGN, rTMP2, 60
	beq	L(CacheAligned)
	add	rMEMP, rMEMP, rALIGN
/* The cr6 and cr7 fields together will hold the number of bytes to set to
   make the destination address cache line aligned */
	mtcrf	0x03, rALIGN
	sub	rLEN, rLEN, rALIGN
	cmplwi	cr1, rALIGN, 32
	mr	rMEMP2, rMEMP
	bf	cr6*4+3, L(a1)
	std	rCHR, -8(rMEMP2)
	stdu	rCHR, -16(rMEMP2)
L(a1):
	blt	cr1, L(a2)
	std	rCHR, -8(rMEMP2)
	std	rCHR, -16(rMEMP2)
	std	rCHR, -24(rMEMP2)
	stdu	rCHR, -32(rMEMP2)
L(a2):
	bf	cr7*4, L(CacheAligned)
	std	rCHR, -8(rMEMP2)
/* Now the address is aligned to cache line boundary */
L(CacheAligned):
#ifdef SHARED
	mflr	rTMP
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
/* The data cache instructions should be used only if the cache line
   size is 64 bytes. This check is required to not to break the memset
   when this code is being verified on machines having cache line size
   other than 64 bytes */
	cmplwi	cr5, rCLS, 64
	cmplwi	cr1, rCHR, 0
	bne	cr5, L(NonDcbzLoopStart)
	beq	cr1, L(zLoopStart)
L(nzLoopStart):
	srwi	rALIGN, rLEN, 6		/* count = n / CACHE_LINE_SIZE */
	rlwinm	rMEMP2, rLEN, 0, 0, 25
	rlwinm	rLEN, rLEN, 0, 26, 31	/* n = n % CACHE_LINE_SIZE */
	subic.	rCNT, rALIGN, 2048
	add	rMEMP, rMEMP, rMEMP2
	li	rNEG128, -0x80
	ble	L(nzLoopBigDone)
	mtctr	rCNT
	b	L(nzLoopBig)
	.align	6
/* Memset 64 bytes per iteration. Though we are in 32 bit mode, the
   GPR registers are still 64 bits and we can do store integer double
   operations */
L(nzLoopBig):
/* The 'dcbzl' here clears the entire cache line and hints the core that
   the data in the <rNEG128+rMEMP> cache block is new and hence no need
   to fetch the block from either L2 cache or main memory and that will
   save us some cycles */
	dcbzl	rNEG128, rMEMP
	std	rCHR, -8(rMEMP)
	std	rCHR, -16(rMEMP)
	std	rCHR, -24(rMEMP)
	std	rCHR, -32(rMEMP)
	std	rCHR, -40(rMEMP)
	std	rCHR, -48(rMEMP)
	std	rCHR, -56(rMEMP)
	stdu	rCHR, -64(rMEMP)
	bdnz	L(nzLoopBig)	
	li	rALIGN, 2048
L(nzLoopBigDone):
	cmplwi	cr1, rALIGN, 0
	srwi.	rTMP2, rLEN, 5
	beq	cr1, L(nzLoopSmallDone)
	mtctr	rALIGN
/* Like above, memset 64 bytes per iteration but do not use the 'dcbzl'
   instruction because using it will cost more than cache prefetching for
   small number of cache blocks */
L(nzLoopSmall):
	std	rCHR, -8(rMEMP)
	std	rCHR, -16(rMEMP)
	std	rCHR, -24(rMEMP)
	std	rCHR, -32(rMEMP)
	std	rCHR, -40(rMEMP)
	std	rCHR, -48(rMEMP)
	std	rCHR, -56(rMEMP)
	stdu	rCHR, -64(rMEMP)
	bdnz	L(nzLoopSmall)
L(nzLoopSmallDone):
/* Memset the residual bytes */
	add	rMEMP, rMEMP, rMEMP2
	beq	L(Upto31Bytes)
	andi.	rLEN, rLEN, 31
	std	rCHR, 0(rMEMP)
	std	rCHR, 8(rMEMP)
	std	rCHR, 16(rMEMP)
	std	rCHR, 24(rMEMP)
	addi	rMEMP, rMEMP, 32
	beqlr
	b	L(Upto31Bytes)

/* We are here because the cache line size is not 64 bytes. Memset
   64 bytes per each iteration without using the data cache instructions */
	.align	6
L(NonDcbzLoopStart):
	srwi.	rALIGN, rLEN, 6         /* count = n / CACHE_LINE_SIZE */
	beq	L(NonDcbzLoopDone)
	rlwinm	rLEN, rLEN, 0, 26, 31   /* n = n % CACHE_LINE_SIZE */
	mtctr	rALIGN
/* Though we are in 32 bit mode, the GPR registers are still 64 bits
   and we can do store integer double operations */
L(NonDcbzLoop):
	std	rCHR, 0(rMEMP)
	std	rCHR, 8(rMEMP)
	std	rCHR, 16(rMEMP)
	std	rCHR, 24(rMEMP)
	std	rCHR, 32(rMEMP)
	std	rCHR, 40(rMEMP)
	std	rCHR, 48(rMEMP)
	std	rCHR, 56(rMEMP)
	addi	rMEMP, rMEMP, 64
	bdnz	L(NonDcbzLoop)
L(NonDcbzLoopDone):
/* Memset the residual bytes */
	srwi.	rTMP2, rLEN, 5
	beq	L(Upto31Bytes)
	andi.	rLEN, rLEN, 31
	std	rCHR, 0(rMEMP)
	std	rCHR, 8(rMEMP)
	std	rCHR, 16(rMEMP)
	std	rCHR, 24(rMEMP)
	addi	rMEMP, rMEMP, 32
	beqlr
	b	L(Upto31Bytes)

	.align 6
/* Memset of 7 bytes or less  */
L(upTo7Bytes):
	cmplwi	cr5, rLEN, 2
	bf	cr7*4+3, L(b1)
	stbu	rCHR, -1(rMEMP2)
	bltlr	cr5
L(b1):
	rlwimi	rCHR, rCHR, 8, 16, 23	/* Replicate byte to halfword */
	bf	cr7*4+2, L(b2)
	sthu	rCHR, -2(rMEMP2)
	bflr	cr7*4+1
L(b2):
	rlwimi	rCHR, rCHR, 16, 0, 15	/* Replicate half word to word */
	bflr	cr7*4+1
	stw	rCHR, -4(rMEMP2)
	blr

	.align 6
/* Memset of 0-31 bytes.  This code gets invoked only when the size, which
   is not the tail bytes size, is less than 32 bytes */
L(nAupTo31Bytes):
	insrdi	rCHR, rCHR, 32, 0	/* Replicate word to double word */
	beq	cr5, L(nA31)
	cmplwi	cr1, rLEN, 16
	bf	31, L(nA2)
	stbu	rCHR, -1(rMEMP2)
L(nA2):
	bf	30, L(nA4)
	sthu	rCHR, -2(rMEMP2)
L(nA4):
	bf	29, L(nA8)
	stwu	rCHR, -4(rMEMP2)
L(nA8):
	bf	28, L(nA16)
	stdu	rCHR, -8(rMEMP2)
L(nA16):
	bltlr	cr1
	std	rCHR, -8(rMEMP2)
	std	rCHR, -16(rMEMP2)
	blr
L(nA31):
	std	rCHR, 0(rMEMP0)
	std	rCHR, 8(rMEMP0)
	std	rCHR, 16(rMEMP0)
	stw	rCHR, 24(rMEMP0)
	sth	rCHR, 28(rMEMP0)
	stb	rCHR, 30(rMEMP0)
	blr


/* Clear cache lines of memory in 256-byte chunks per iteration using
   the data cache block zero line instruction */
	.align	6
L(zLoopStart):
	cmplwi	cr5, rLEN, 256
	andi.	rTMP, rLEN, 128
	li	rPOS64, 64
	blt	cr5, L(zLoopDone)
	li	rPOS128, 128
	li	rPOS192, 192
L(zLoop):
	subic	rLEN, rLEN, 256
	dcbzl	0, rMEMP
	cmplwi	cr1, rLEN, 256
	dcbzl	rPOS64, rMEMP
	dcbzl	rPOS128, rMEMP
	dcbzl	rPOS192, rMEMP
	addi	rMEMP, rMEMP, 256
	bge	cr1, L(zLoop)
L(zLoopDone):
	beq	L(z1)
	dcbzl	0, rMEMP
	dcbzl	rPOS64, rMEMP
	addi	rMEMP, rMEMP, 128
L(z1):
	andi.	rTMP2, rLEN, 64
	beq	L(z0)
	dcbzl	0, rMEMP
	addi	rMEMP, rMEMP, 64
L(z0):
/* Memset the residual bytes. Though we are in 32 bit mode, the GPR
   registers are still 64 bits and we can do store integer double operations */
	andi.	rTMP2, rLEN, 32
	rlwinm	rLEN, rLEN, 0, 27, 31
	beq	L(Upto31Bytes)
	rlwinm.	rLEN, rLEN, 0, 27, 31
	std	rCHR, 0(rMEMP)
	std	rCHR, 8(rMEMP)
	std	rCHR, 16(rMEMP)
	std	rCHR, 24(rMEMP)
	beqlr
	addi	rMEMP, rMEMP, 32
	b	L(Upto31Bytes)

/* Memset of 0-31 bytes.  */
	.align	6
L(Upto31Bytes):
	mtcrf	0x01, rLEN
	cmplwi	cr1, rLEN, 16
	add	rMEMP, rMEMP, rLEN
	bt	cr7*4+3, L(b31t)
	bt	cr7*4+2, L(b30t)
L(b30f):
	bt	cr7*4+1, L(b29t)
L(b29f):
	bge	cr1, L(b27t)
	bflr	cr7*4
	std	rCHR, -8(rMEMP)
	blr

L(b31t):
	stbu	rCHR, -1(rMEMP)
	bf	cr7*4+2, L(b30f)
L(b30t):
	sthu	rCHR, -2(rMEMP)
	bf	cr7*4+1, L(b29f)
L(b29t):
	stwu	rCHR, -4(rMEMP)
	blt	cr1, L(b27f) 
L(b27t):
	std	rCHR, -8(rMEMP)
	stdu	rCHR, -16(rMEMP)
L(b27f):
	bflr	cr7*4
L(b28t):
	std	rCHR, -8(rMEMP)
	blr

END (memset)
libc_hidden_builtin_def (memset)

