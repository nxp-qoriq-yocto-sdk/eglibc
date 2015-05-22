/*------------------------------------------------------------------
 * memcpy.S
 *
 * Standard memcpy function optimized for e500 using SPE.  This
 * function does not handle overlap, as per spec.  This file is
 * identical to the memmove.S file.  To get a memmove out of it,
 * specify -D__MEMMOVE__ to the compiler
 *
 *------------------------------------------------------------------
 *      Copyright (c) 2005 Freescale Semiconductor, Inc
 *      ALL RIGHTS RESERVED
 *
 *	Redistribution and use in source and binary forms, with or
 *	without modification, are permitted provided that the following
 *	conditions are met:
 *	
 *	
 *	Redistributions of source code must retain the above copyright
 *	notice, this list of conditions and the following disclaimer.
 *	
 *	Redistributions in binary form must reproduce the above copyright
 *	notice, this list of conditions and the following disclaimer in
 *	the documentation and/or other materials provided with the
 *	distribution.
 *	
 *	Neither the name of Freescale Semiconductor, Inc nor the names of
 *	its contributors may be used to endorse or promote products derived
 *	from this software without specific prior written permission.
 *	
 *	
 *	
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 *	CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 *	INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 *	MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *	DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
 *	BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *	EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *	TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 *	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 *	ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 *	OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 *	OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 *------------------------------------------------------------------
 */

#include <sysdep.h>

/*------------------------------------------------------------------
 * int memcpy(const unsigned char* dst,
 *            const unsigned char* src,
 *            long count);
 * void * memmove(const unsigned char* dst,
 *                const unsigned char* src,
 *                long count);
 * Returns:
 *  dst
 *------------------------------------------------------------------
 */

#ifdef __MEMMOVE__
	.file	"memmove.S"
#else /* memcpy */
	.file	"memcpy.S"
#endif /* __MEMMOVE */
	.section	".text"
	.align 4
#ifdef __MEMMOVE__
	#define FUNCTION memmove
#else /* memcpy */
	#define FUNCTION memcpy
#endif /* __MEMMOVE__ */
EALIGN (FUNCTION, 5, 1)

/* Prologs are different for memcpy and memmove.  memmove needs
 * to handle the case where the buffers overlap correctly.
 * memcpy does not.  In order to make the implementation simple,
 * memmove ONLY copies backwards if it needs to, and only for as 
 * much as is necessary to remove the overlap.
 */
#ifdef __MEMMOVE__
        or r0,r4,r3
        subf r9,r4,r3
        mr r6,r3
        subf r11,r9,r5
        andi. r0,r0,7
        rlwinm r9,r9,0,0,0
        xor r0,r4,r6
        bne L(memcpy_unaligned)

        or. r11,r9,r11
        bgt L(Handle_Overlap)

/* memcpy is simpler */
#else /* memcpy */

        or r0,r4,r3
        mr r6,r3
        andi. r0,r0,7
        xor r0,r4,r6
        bne L(memcpy_unaligned)

#endif /* __MEMMOVE__ */

L(aligned_copy):
        srwi. r12,r5,5
        mtcrf 0x2,r5
        mtcrf 0x1,r5
        bne L(big_loop)

L(try_two_doubles):
        bf 27,L(try_one_double)
        evldd r7,0(r4)
        evstdd r7,0(r6)
        evldd r8,8(r4)
        addi r4,r4,16
        evstdd r8,8(r6)
        addi r6,r6,16

L(try_one_double):
        bf 28,L(try_word)
        evldd r7,0(r4)
        addi r4,r4,8
        evstdd r7,0(r6)
        addi r6,r6,8

L(try_word):
        bf 29,L(try_half)
        lwz r7,0(r4)
        addi r4,r4,4
        stw r7,0(r6)
        addi r6,r6,4

L(try_half):
        bf 30,L(try_byte)
        lhz r7,0(r4)
        addi r4,r4,2
        sth r7,0(r6)
        addi r6,r6,2

L(try_byte):
        bf 31,L(finish)
        lbz r7,0(r4)
        stb r7,0(r6)

L(finish):
        blr

L(big_loop):
        evldd r7,0(r4)
        addic. r12,r12,-1
        evldd r8,8(r4)
        evldd r9,16(r4)
        evldd r10,24(r4)
        addi r4,r4,32
        evstdd r7,0(r6)
        evstdd r8,8(r6)
        evstdd r9,16(r6)
        evstdd r10,24(r6)
        addi r6,r6,32
        bne L(big_loop)

        b L(try_two_doubles)

L(align_dest_word):
L(align_dest_double):
        /* First make sure there are at least 8 bytes left to
	 * copy.  Otherwise, realignment could go out of bounds
	 */
        cmpwi r5,8
        neg r0,r6
        blt L(small_copy)

        andi. r7,r6,0x3
        mtcrf 0x1,r0

        bne L(more_alignment)

/* Don't need to check if r6 needs another word to be aligned.
 * We're here, therefore we must have only been off by a word.
 * So we shorten the path a bit by taking 2 branches out from the
 * more common path (ie things tend to be at least word-aligned)
 */
L(align_one_word):
        lwz r7,0(r4)
        addi r4,r4,4
        stw r7,0(r6)
        addi r6,r6,4
        addi r5,r5,-4
        bne cr6,L(unaligned_double_copy)
        b L(aligned_copy)

L(more_alignment):
        bf 31, L(try_align_word)
        lbz r7,0(r4)
        addi r4,r4,1
        stb r7,0(r6)
        addi r6,r6,1
        addi r5,r5,-1

L(try_align_word):
        bf 30, L(try_align_double)
        lhz r7,0(r4)
        addi r4,r4,2
        sth r7,0(r6)
        addi r6,r6,2
        addi r5,r5,-2

L(try_align_double):
        bt 29, L(align_one_word)
        beq cr6,L(aligned_copy)

/* For each double word copied, we load the double words with
 * each half from r4 (which starts at 0x*4 or 0x*c).  Then we
 * use evmergelohi to take the halves and rejoin them.  Notice
 * that any double load will necessarily be 4 bytes ahead.
 * Invariant: at the start of any block (except the first) which
 * loads a doubleword, r10 will hold the first half of the
 * first doubleword
 */
L(unaligned_double_copy):
        /* align r4 to a doubleword boundary */
        rlwinm r4,r4,0,0,28
        srwi. r12, r5,5

        /* grab the first doubleword */
        evldd r10,0(r4)

	/* Set the CR to indicate how many bytes remain to be
	 * copied after the big loop is done */
        mtcrf 0x2,r5
        mtcrf 0x1,r5
        bne L(unaligned_big_loop)

/* There are less than 4 double words left, so we take care of
 * them
 */
L(try_unaligned_2_doubles):
        bf 27, L(try_unaligned_double)
        evldd r9,8(r4)
        evmergelohi r10,r10,r9
        evstdd r10,0(r6)
        evldd r10,16(r4)
        addi r4,r4,16
        evmergelohi r9,r9,r10
        evstdd r9,8(r6)
        addi r6,r6,16

L(try_unaligned_double):
        bf 28, L(try_unaligned_word)
        evldd r9,8(r4)
        addi r4,r4,8
        evmergelohi r10,r10,r9
        evstdd r10,0(r6)
        addi r6,r6,8
        evmr r10,r9

L(try_unaligned_word):
        addi r4,r4,4
        bf 29, L(try_unaligned_half)
        stw r10,0(r6)
        addi r4,r4,4
        addi r6,r6,4

L(try_unaligned_half):
        bf 30, L(try_unaligned_byte)
        lhz r10,0(r4)
        addi r4,r4,2
        sth r10,0(r6)
        addi r6,r6,2

L(try_unaligned_byte):
        bf 31, L(finish)
        lbz r10,0(r4)
        stb r10,0(r6)
        blr

L(unaligned_big_loop):
        evldd r7,8(r4)
        evldd r8,16(r4)
        addic. r12,r12,-1
        evldd r9,24(r4)
        addi r4,r4,32
        evmergelohi r10,r10,r7
        evstdd r10,0(r6)
        evmergelohi r7,r7,r8
        evldd r10,0(r4)
        evmergelohi r8,r8,r9
        evstdd r7,8(r6)
        evmergelohi r9,r9,r10
        evstdd r8,16(r6)
        evstdd r9,24(r6)
        addi r6,r6,32
        bne L(unaligned_big_loop)
        b L(try_unaligned_2_doubles)


L(small_copy):
        mtcrf 0x1,r5
        bf 29,L(try_small_half)
        lbz r7,0(r4)
        lbz r8,1(r4)
        lbz r9,2(r4)
        lbz r10,3(r4)
        addi r4,r4,4
        stb r7,0(r6)
        stb r8,1(r6)
        stb r9,2(r6)
        stb r10,3(r6)
        addi r6,r6,4

L(try_small_half):
        bf 30,L(try_small_byte)
        lbz r7,0(r4)
        lbz r8,1(r4)
        addi r4,r4,2
        stb r7,0(r6)
        stb r8,1(r6)
        addi r6,r6,2

L(try_small_byte):
        bf 31, L(finish)
        lbz r7,0(r4)
        stb r7,0(r6)
        blr

L(memcpy_unaligned):
#ifdef __MEMMOVE__

        or. r11,r9,r11
        bgt L(Handle_Overlap)

L(choose_alignment):
#endif /* __MEMMOVE */
        /* If both pointers can be double-aligned, align r6,
	 * setting eq6 to indicate "aligned
	 */
        rlwinm. r0,r0,0,29,31
        cmpw cr6,r31,r31 /* set eq6 */

        /* Look at r6 to see if we're aligned already (but not
	 * both aligned, which is why we're here)
	 */
        rlwinm r7,r6,0,29,31
        beq L(align_dest_double)

        /* Compare to find out if r6 is already doublealigned
	 * If both pointers can be word-aligned, align r6,
	 * clearing eq6 to indicate unaligned
	 */
        rlwinm. r0,r0,0,30,31
        cmpwi cr1,r7,0

        /* Only skip to unaligned_double_copy if r6 is aligned,
	 * AND r0 indicates word-alignment
	 */
        crand 6,6,2

        crxor 26,26,26 /* clear eq6 */
        beq cr1,L(unaligned_double_copy)
        beq L(align_dest_word)

        /* Before we hop into bytewise copying, make sure that
	 * there are bytes to copy (don't want to loop 4 billion+
	 * times!
	 */
        cmpwi r5,0
        beqlr

        /* Well, alignment is just icky, copy bytewise */
        mtctr r5
L(byte_copy):
        lbz r7,0(r4)
        addi r4,r4,1
        stb r7,0(r6)
        addi r6,r6,1
        bdnz L(byte_copy)
        blr

#ifdef __MEMMOVE__


        /* If the regions being copied overlap, and r4 is lower
	 * in memory than r6, then we need to copy backward
	 * until the overlap is gone, then just do the normal
	 * copy
	 */
L(Handle_Overlap):
        /* r11 has the size of the overlap */
        add r8,r6,r5
        add r10,r4,r5

        mtctr r11

L(bkw_fix_loop):
        lbzu r9,-1(r10)
        stbu r9,-1(r8)
        bdnz L(bkw_fix_loop)

        /* We're done, correct r5, and return */
        subf r5,r11,r5

        b FUNCTION@local
#endif /* __MEMMOVE */

END (FUNCTION)
libc_hidden_builtin_def (FUNCTION)

#ifndef __MEMMOVE__
weak_alias (memcpy,largememcpy)
libc_hidden_def (largememcpy)
#endif
