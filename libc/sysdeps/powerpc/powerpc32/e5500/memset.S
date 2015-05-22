/* Optimized memset implementation for PowerPC/e5500 32 bit target.
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

#include <sysdep.h>

/* __ptr_t [r3] memset (__ptr_t s [r3], int c [r4], size_t n [r5]));
   Returns 's'.

   The memset is done in three sizes: byte (8 bits), word (32 bits)
   and __cache_line_size (512 bits). There is a special case for setting
   whole cache lines to 0, which takes advantage of the dcbzl instruction. */

	.section	".text"
EALIGN (memset, 6, 1)

#define rTMP	r0
#define rMEMP0	r3	/* original value of 1st arg */
#define rCHR	r4	/* char to set in each byte */
#define rLEN	r5	/* length of region to set */
#define rMEMP	r6	/* address at which we are storing */
#define rALIGN	r7	/* number of bytes we are setting now (when aligning) */
#define	rTMP2	r8
#define rMEMP2	r9
#define rCNT	r0

#define rPOS64	r10	/* constant +64 for clearing with dcbz */
#define rCLS	r11
#define rGOT	r12

#ifndef _SOFT_FLOAT
#define rFLD	fp0	/* float double register with char(s) to set in each byte */
#endif

/* For sizes <= 4 bytes, do byte by byte set */
	cmplwi	cr1, rLEN, 4
	mr	rMEMP, rMEMP0
	ble	cr1, L(le_4bytes)
	rlwimi	rCHR, rCHR, 8, 16, 23
	andi.	rALIGN, rMEMP, 3
	rlwimi	rCHR, rCHR, 16, 0, 15
	beq	L(4b_aligned)
/* By now, we know that there are at least 5 bytes to memset and the destination
   address is not word aligned. Do not bother about non-alignment and do a one
   word store at once and word align the destination address. The penalty for
   non-aligned store is less compared to the if-else checks and related code */
	subfic	rALIGN, rALIGN, 4
	stw	rCHR, 0(rMEMP0)	
	sub	rLEN, rLEN, rALIGN
	add	rMEMP, rMEMP, rALIGN
L(4b_aligned):
/* For sizes < 32 bytes, do it in a combination of word/half word/byte stores */
	srwi.	rALIGN, rLEN, 5
	beq	L(lt_32bytes)
/* For sizes where 128 > size >= 32, do the memset in a loop where 32 bytes are
   set per each iteration. For this size range, the overhead in getting the
   destination address cache aligned is more compared to the advantage of setting
   cache line size (64) bytes per iteration */
	srwi.	rTMP2, rALIGN, 2
	bne	L(set_cache_lines)
	mtctr	rALIGN
/* By now, we know that there are at least 32 bytes to memset. Hence no need
   to check for zero loop count */
L(32b_loop):
	stw	rCHR, 0(rMEMP)
	stw	rCHR, 4(rMEMP)
	stw	rCHR, 8(rMEMP)
	stw	rCHR, 12(rMEMP)
	stw	rCHR, 16(rMEMP)
	stw	rCHR, 20(rMEMP)
	stw	rCHR, 24(rMEMP)
	stw	rCHR, 28(rMEMP)
	addi	rMEMP, rMEMP, 32
	bdnz	L(32b_loop)
	rlwinm.	rLEN, rLEN, 0, 27, 31
	beqlr
	b	L(lt_32bytes)

L(set_cache_lines):
	neg	rTMP2, rMEMP
	andi.	rALIGN, rTMP2, 60
	beq	L(cache_aligned)
	add	rMEMP, rMEMP, rALIGN
/* The cr6 and cr7 fields together will hold the number of bytes to set to
   make the destination address cache line aligned */
	mtcrf	0x03, rALIGN
	sub	rLEN, rLEN, rALIGN
	cmplwi	cr1, rALIGN, 32
	mr	rMEMP2, rMEMP
	bf	cr6*4+3, L(a1)
	stw	rCHR, -4(rMEMP2)
	stw	rCHR, -8(rMEMP2)
	stw	rCHR, -12(rMEMP2)
	stwu	rCHR, -16(rMEMP2)
L(a1):
	blt	cr1, L(a2)
	stw	rCHR, -4(rMEMP2)
	stw	rCHR, -8(rMEMP2)
	stw	rCHR, -12(rMEMP2)
	stw	rCHR, -16(rMEMP2)
	stw	rCHR, -20(rMEMP2)
	stw	rCHR, -24(rMEMP2)
	stw	rCHR, -28(rMEMP2)
	stwu	rCHR, -32(rMEMP2)
L(a2):
	bf	cr7*4, L(a3)
	stw	rCHR, -4(rMEMP2)
	stwu	rCHR, -8(rMEMP2)
L(a3):
	bf	cr7*4+1, L(cache_aligned)
	stw	rCHR, -4(rMEMP2)

L(cache_aligned):
#ifdef SHARED
	mflr rTMP
/* Establishes GOT addressability so we can load __cache_line_size
   from static. This value was set from the aux vector during startup. */
	SETUP_GOT_ACCESS(rGOT,got_label_1)
	addis	rGOT, rGOT, __cache_line_size-got_label_1@ha
	lwz	rCLS, __cache_line_size-got_label_1@l(rGOT)
	mtlr	rTMP
#else
/* Load __cache_line_size from static. This value was set from the
   aux vector during startup. */
	lis	rCLS,__cache_line_size@ha
	lwz	rCLS,__cache_line_size@l(rCLS)
#endif
/* If the cache line size is set and is 64 bytes, do the memset using
   data cache block instructions i.e. dcbz etc. Otherwise do not use
   the dcb* instructions */
	cmplwi	cr5, rCLS, 64
	cmplwi	cr1, rCHR, 0
	bne	cr5, L(nondcbz_loop_start)
	beq	cr1, L(z_loop_start)
L(nz_loop_start):
#ifndef _SOFT_FLOAT
	stw	rCHR, 0(rMEMP)
	srwi	rALIGN, rLEN, 6		/* count = n / CACHE_LINE_SIZE */
	stw	rCHR, 4(rMEMP)
	rlwinm	rLEN, rLEN, 0, 26, 31	/* n = n % CACHE_LINE_SIZE */
	subic.	rCNT, rALIGN, 4
	lfd	rFLD, 0(rMEMP)
#else
	srwi	rALIGN, rLEN, 6		/* count = n / CACHE_LINE_SIZE */
	rlwinm	rLEN, rLEN, 0, 26, 31	/* n = n % CACHE_LINE_SIZE */
	subic.	rCNT, rALIGN, 4	
#endif
	li	rPOS64, 64
	ble	L(nz_loop_big_done)
	mtctr	rCNT
L(nz_loop_big):
	dcbzl	rPOS64, rMEMP
#ifndef _SOFT_FLOAT
        stfd    rFLD, 0(rMEMP)
        stfd    rFLD, 8(rMEMP)
        stfd    rFLD, 16(rMEMP)
        stfd    rFLD, 24(rMEMP)
        stfd    rFLD, 32(rMEMP)
        stfd    rFLD, 40(rMEMP)
        stfd    rFLD, 48(rMEMP)
        stfd    rFLD, 56(rMEMP)
#else
        stw     rCHR, 0(rMEMP)
        stw     rCHR, 4(rMEMP)
        stw     rCHR, 8(rMEMP)
        stw     rCHR, 12(rMEMP)
        stw     rCHR, 16(rMEMP)
        stw     rCHR, 20(rMEMP)
        stw     rCHR, 24(rMEMP)
        stw     rCHR, 28(rMEMP)
        stw     rCHR, 32(rMEMP)
        stw     rCHR, 36(rMEMP)
        stw     rCHR, 40(rMEMP)
        stw     rCHR, 44(rMEMP)
        stw     rCHR, 48(rMEMP)
        stw     rCHR, 52(rMEMP)
        stw     rCHR, 56(rMEMP)
        stw     rCHR, 60(rMEMP)
#endif
	addi	rMEMP, rMEMP, 64
	bdnz	L(nz_loop_big)	
	li	rALIGN, 4
L(nz_loop_big_done):
	cmplwi	cr1, rALIGN, 0
	beq	cr1, L(nz_loop_small_done)
	mtctr	rALIGN
L(nz_loop_small):
#ifndef _SOFT_FLOAT
	stfd	rFLD, 0(rMEMP)
	stfd	rFLD, 8(rMEMP)
	stfd	rFLD, 16(rMEMP)
	stfd	rFLD, 24(rMEMP)
	stfd	rFLD, 32(rMEMP)
	stfd	rFLD, 40(rMEMP)
	stfd	rFLD, 48(rMEMP)
	stfd	rFLD, 56(rMEMP)
#else
	stw	rCHR, 0(rMEMP)
	stw	rCHR, 4(rMEMP)
	stw	rCHR, 8(rMEMP)
	stw	rCHR, 12(rMEMP)
	stw	rCHR, 16(rMEMP)
	stw	rCHR, 20(rMEMP)
	stw	rCHR, 24(rMEMP) 
	stw	rCHR, 28(rMEMP)
	stw	rCHR, 32(rMEMP)
	stw	rCHR, 36(rMEMP)
	stw	rCHR, 40(rMEMP)
	stw	rCHR, 44(rMEMP)
	stw	rCHR, 48(rMEMP)
	stw	rCHR, 52(rMEMP)
	stw	rCHR, 56(rMEMP) 
	stw	rCHR, 60(rMEMP)
#endif
	addi	rMEMP, rMEMP, 64
	bdnz	L(nz_loop_small)
L(nz_loop_small_done):
	srwi.	rTMP2, rLEN, 5
	beq	L(lt_32bytes)
#ifndef _SOFT_FLOAT
        stfd    rFLD, 0(rMEMP)
        stfd    rFLD, 8(rMEMP)
        stfd    rFLD, 16(rMEMP)
        stfd    rFLD, 24(rMEMP)
#else
        stw     rCHR, 0(rMEMP)
        stw     rCHR, 4(rMEMP)
        stw     rCHR, 8(rMEMP)
        stw     rCHR, 12(rMEMP)
        stw     rCHR, 16(rMEMP)
        stw     rCHR, 20(rMEMP)
        stw     rCHR, 24(rMEMP)
        stw     rCHR, 28(rMEMP)
#endif
	andi.	rLEN, rLEN, 31
	addi	rMEMP, rMEMP, 32
	beqlr
	b	L(lt_32bytes)

	.p2align 6
L(nondcbz_loop_start):
        srwi.	rALIGN, rLEN, 6         /* count = n / CACHE_LINE_SIZE */
	beq	L(nondcbz_loop_done)
#ifndef _SOFT_FLOAT
        stw     rCHR, 0(rMEMP)
        stw     rCHR, 4(rMEMP)
        rlwinm  rLEN, rLEN, 0, 26, 31   /* n = n % CACHE_LINE_SIZE */
        lfd     rFLD, 0(rMEMP)
#else
        rlwinm  rLEN, rLEN, 0, 26, 31   /* n = n % CACHE_LINE_SIZE */
#endif
        mtctr   rALIGN
L(nondcbz_loop):
#ifndef _SOFT_FLOAT
        stfd    rFLD, 0(rMEMP)
        stfd    rFLD, 8(rMEMP)
        stfd    rFLD, 16(rMEMP)
        stfd    rFLD, 24(rMEMP)
        stfd    rFLD, 32(rMEMP)
        stfd    rFLD, 40(rMEMP)
        stfd    rFLD, 48(rMEMP)
        stfd    rFLD, 56(rMEMP)
#else
        stw     rCHR, 0(rMEMP)
        stw     rCHR, 4(rMEMP)
        stw     rCHR, 8(rMEMP)
        stw     rCHR, 12(rMEMP)
        stw     rCHR, 16(rMEMP)
        stw     rCHR, 20(rMEMP)
        stw     rCHR, 24(rMEMP)
        stw     rCHR, 28(rMEMP)
        stw     rCHR, 32(rMEMP)
        stw     rCHR, 36(rMEMP)
        stw     rCHR, 40(rMEMP)
        stw     rCHR, 44(rMEMP)
        stw     rCHR, 48(rMEMP)
        stw     rCHR, 52(rMEMP)
        stw     rCHR, 56(rMEMP)
        stw     rCHR, 60(rMEMP)
#endif
        addi    rMEMP, rMEMP, 64
        bdnz    L(nondcbz_loop)
L(nondcbz_loop_done):
        srwi.   rTMP2, rLEN, 5
        beq     L(lt_32bytes)
        stw     rCHR, 0(rMEMP)
        stw     rCHR, 4(rMEMP)
        stw     rCHR, 8(rMEMP)
        stw     rCHR, 12(rMEMP)
        stw     rCHR, 16(rMEMP)
        stw     rCHR, 20(rMEMP)
        stw     rCHR, 24(rMEMP)
        stw     rCHR, 28(rMEMP)
        andi.   rLEN, rLEN, 31
        addi    rMEMP, rMEMP, 32
        beqlr
        b       L(lt_32bytes)

/* Memset of 4 bytes or less.  */
	.p2align 6
L(le_4bytes):
	cmplwi	cr5, rLEN, 0
	beqlr	cr5
	cmplwi	cr1, rLEN, 1
	stb	rCHR, 0(rMEMP)
	beqlr	cr1
	cmplwi	cr5, rLEN, 2
	stb	rCHR, 1(rMEMP)
	beqlr	cr5
	cmplwi	cr1, rLEN, 4
	stb	rCHR, 2(rMEMP)
	bnelr	cr1
	stb	rCHR, 3(rMEMP)
	blr

/* Clear cache lines of memory in 128-byte chunks per iteration using
   the data cache block zero line instruction */
	.p2align 6
L(z_loop_start):
	cmplwi	cr1, rLEN, 128
	li	rPOS64, 64
L(z_loop):
	blt	cr1, L(z_loop_done)
	addi	rLEN, rLEN, -128
	dcbzl	0, rMEMP
	dcbzl	rPOS64, rMEMP
	cmplwi	cr1, rLEN, 128
	addi	rMEMP, rMEMP, 128
	b	L(z_loop)
L(z_loop_done):
	cmplwi	cr5, rLEN, 64
	andi.	rTMP2, rLEN, 32
	blt	cr5, L(z0)
	dcbzl	0, rMEMP
	addi	rLEN, rLEN, -64
	addi	rMEMP, rMEMP, 64
L(z0):
	beq	L(lt_32bytes)
	stw	rCHR, 0(rMEMP)
	stw	rCHR, 4(rMEMP)
	stw	rCHR, 8(rMEMP)
	stw	rCHR, 12(rMEMP)
	stw	rCHR, 16(rMEMP)
	stw	rCHR, 20(rMEMP)
	andi.	rLEN, rLEN, 31
	stw	rCHR, 24(rMEMP)
	stw	rCHR, 28(rMEMP)
	addi	rMEMP, rMEMP, 32
	beqlr

/* Memset of 0-31 bytes. */
L(lt_32bytes):
	mtcrf   0x01, rLEN
	cmplwi	cr1, rLEN, 16
	add	rMEMP, rMEMP, rLEN
	bt	31, L(b31t)
	bt	30, L(b30t)
L(b30f):
	bt	29, L(b29t)
L(b29f):
	bge	cr1, L(b27t)
	bflr	28
	stw	rCHR, -4(rMEMP)	
	stw	rCHR, -8(rMEMP)
	blr
L(b31t):
	stbu	rCHR, -1(rMEMP)
	bf	30, L(b30f)
L(b30t):
	sthu	rCHR, -2(rMEMP)
	bf	29, L(b29f)
L(b29t):
	stwu	rCHR, -4(rMEMP)
	blt	cr1, L(b27f) 
L(b27t):
	stw	rCHR, -4(rMEMP)
	stw	rCHR, -8(rMEMP)
	stw	rCHR, -12(rMEMP)
	stwu	rCHR, -16(rMEMP)
L(b27f):
	bflr	28
L(b28t):
	stw	rCHR, -4(rMEMP)
	stw	rCHR, -8(rMEMP)
	blr

END (memset)
libc_hidden_builtin_def (memset)

