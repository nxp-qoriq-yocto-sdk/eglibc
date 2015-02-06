/*------------------------------------------------------------------
 * memset.S
 *
 * Standard memset function optimized for e500 using SPE
 *
 * Copyright (c) 2005 Freescale Semiconductor, Inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of Freescale Semiconductor nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY Freescale Semiconductor ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL Freescale Semiconductor BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *------------------------------------------------------------------
 */

#include <sysdep.h>

/*------------------------------------------------------------------
 * void * memset(void *origdest, int value, size_t len)
 *
 * returns dest
 *
 *------------------------------------------------------------------
 */


	.file	"memset.S"
	.section	".text"
EALIGN (memset, 5, 0)
        /* Find out whether the destination buffer is already
	 * aligned, and propagate the byte through the entire
	 * word.
	 */
        andi. r0,r3,0x7
        rlwimi r4,r4,8,16,23

        /* Check if value (r4) is zero (most common case).  If it
	 * is, we jump to bzero
	 */
        cmpwi cr1,r4,0

        rlwimi r4,r4,16,0,15

        /* If r4 is 0, then we will jump to bzero.  If so,
	 * we want the count to be in the right place for bzero (r4)
	 */
        mr r11,r4
        mr r4,r5

        beq cr1, L(bzero_entry)

        mr r6,r3
        bne L(align_dest_double)

L(aligned_set):
        /* Get the number of doubles/4, since we write 4 at a
	 * time in the big loop.
	 */
        srwi. r12,r5,5

        /* Set the condition register so that each bit represents
	 * some number of bytes to set.
	 */
        mtcrf 0x2,r5
        mtcrf 0x1,r5

        /* Copy r11 up into the hi word, so we can set 8 bytes
	 * at a time.
	 */
        evmergelo r11,r11,r11

        /* If there aren't at least 32 bytes to set, take care of
	 * the last 0-31
	 */
        bne L(big_loop)

/* We only store to memory that we are changing.  No extra loads
 * or stores are done.
 */
L(try_two_doubles):
        bf 27,L(try_one_double)
        evstdd r11,0(r6)
        evstdd r11,8(r6)
        addi r6,r6,16

L(try_one_double):
        bf 28,L(try_word)
        evstdd r11,0(r6)
        addi r6,r6,8
        nop

L(try_word):
        bf 29,L(try_half)
        stw r11,0(r6)
        addi r6,r6,4
        nop

L(try_half):
        bf 30,L(try_byte)
        sth r11,0(r6)
        addi r6,r6,2
        nop

L(try_byte):
        bf 31,L(finish)
        stb r11,0(r6)

L(finish):
        blr

/* Write 32 bytes at a time */
L(big_loop):
        /* adjust r6 back by 8.  We need to do this so we can
	 * hoist the pointer update above the last store in the
	 * loop.  This means that a store can be done every cycle
	 */
        addi r6,r6,-8
L(loop):
        evstdd r11,8(r6)
        addic. r12,r12,-1
        evstdd r11,16(r6)
        evstdd r11,24(r6)
        addi r6,r6,32
        evstdd r11,0(r6)
        bne L(loop)

        /* Readjust r6 */
        addi r6,r6,8
        /* Jump back to take care of the last 0-31 bytes */
        b L(try_two_doubles)

L(align_dest_double):
        /* First make sure there are at least 8 bytes left to
	 * set.  Otherwise, realignment could go out of bounds
	 */
        cmpwi cr1, r5,8

        /* Find out how many bytes we need to set in order to
	 * align r6
	 */
        neg r0,r6
        andi. r7,r6,0x3

        blt cr1, L(small_set)

        /* Set the condition register so that each bit in cr7
	 * represents a number of bytes to write to align r6
	 */
        mtcrf 0x1,r0

        /* The most common case is that r6 is at least
	 * word-aligned, so that is the fall-through case.
	 * Otherwise, we skip ahead to align a bit more.
	 */
        bne L(more_alignment)
L(align_one_word):
        addi r5,r5,-4
        stw r11,0(r6)
        addi r6,r6,4
        b L(aligned_set)

L(more_alignment):
        bf 31, L(try_align_word)
        addi r5,r5,-1
        stb r11,0(r6)
        addi r6,r6,1

L(try_align_word):
        bf 30, L(try_align_double)
        addi r5,r5,-2
        sth r11,0(r6)
        addi r6,r6,2

L(try_align_double):
        bt 29, L(align_one_word)
        b L(aligned_set)

L(small_set):
        mtcrf 0x1,r5
        bf 29,L(try_small_half)
        /* This may be better, but stw SHOULD do the same thing
	 * as fast or faster.  It just has a chance of being
	 * unaligned
	 *	stb	r11,0(r6)
	 *	stb	r11,1(r6)
	 *	stb	r11,2(r6)
	 *	stb	r11,3(r6)
	 */

        stw r11,0(r6)
        addi r6,r6,4

L(try_small_half):
        bf 30,L(try_small_byte)

        /* Storing half should take the same or less time than
	 * two stb, so we do that
	 */
        sth r11,0(r6)
        addi r6,r6,2

L(try_small_byte):
        bf 31, L(finish)
        stb r11,0(r6)
        blr

END (memset)
libc_hidden_builtin_def (memset)

EALIGN (bzero, 5, 0)
L(bzero_entry):
        /* Check dest's alignment (within a cache-line) */
        neg r8,r3

        /* r12, here, is the number of 128 byte chunks to
	 * zero out.
	 */
        srwi r12,r4,7

        /* Find out the number of bytes needed to copy to align
	 * dest to a cacheline boundary
	 */
        andi. r8, r8,0x1f
        cmpwi cr1,r12,0

        /* bzero can be called from memset, so we want it to
	 * return the same value memset would.  This doesn't hurt
	 * anything, so we keep the old value of r3, and copy it
	 * into another register which we are free to change.
	 */
        mr r6,r3

        /* Jump to align r6 if it isn't already aligned */
        bne L(align_dest_32)

        /* r6 is aligned to a cache-line, so we can zero
	 * out using dcbz if the buffer is large enough
	 */
L(zero_aligned):
        /* set the cr bits for the last 0-127 bytes remaining */
        mtcrf 0x1,r4
        mtcrf 0x2,r4

        li r10,-32
        li r9,32
        beq cr1,L(try_two_lines)

        li r11,64

L(zero_loop):
        dcbz 0,r6
        addic. r12,r12,-1
        dcbz r9,r6
        dcbz r11,r6
        addi r6,r6,128
        dcbz r10,r6
        bne L(zero_loop)

L(try_two_lines):
        /* Put 0 into r11 such that memset can handle the last
	 * 0-31 bytes (yay, instruction savings!)
	 */
        evsplati r11,0

        rlwinm. r0, r4,0,27,31

        bf 25, L(try_one_line)
        dcbz 0,r6
        dcbz r9,r6
        addi r6,r6,64

L(try_one_line):
        bf 26, L(try_two_doubles)
        dcbz 0,r6
        addi r6,r6,32

        bne L(try_two_doubles)
        /* there weren't any bytes left, so we return */
        blr

L(align_dest_32):
        /* move r8 into the crfields so that we can align
	 * easily
	 */
        mtcrf 0x1,r8
        mtcrf 0x2,r8

        /* update the counter */
        subf. r4,r8,r4

        /* if r4 is not great enough to align r6, then we
	 * zero in small amounts
	 */
        blt L(zero_small)

        /* zero out a register to store to memory */
        evsplati r8,0

        bf 31,L(zero_one_half)
        stb r8,0(r6)
        addi r6,r6,1
        nop

L(zero_one_half):
        bf 30, L(zero_word)
        sth r8,0(r6)
        addi r6,r6,2
        nop

L(zero_word):
        bf 29, L(zero_double)
        stw r8,0(r6)
        addi r6,r6,4
        nop

L(zero_double):
        bf 28, L(zero_two)
        evstdd r8,0(r6)
        addi r6,r6,8
        nop

L(zero_two):
        bf 27,L(zero_finish)
        evstdd r8,0(r6)
        evstdd r8,8(r6)
        addi r6,r6,16

L(zero_finish):
        srwi. r12,r4,7
        li r9,32
        li r11,64
        li r10,-32

        mtcrf 0x1,r4
        mtcrf 0x2,r4
        bne L(zero_loop)
        b L(try_two_lines)

L(zero_small):
        add r4,r8,r4
        mtcrf 0x1,r4
        mtcrf 0x2,r4

        evsplati r8,0

        bf 27,L(zero_one_small)
        stw r8,0(r6)
        stw r8,4(r6)
        stw r8,8(r6)
        stw r8,12(r6)
        addi r6,r6,16

L(zero_one_small):
        bf 28,L(zero_word_small)
        stw r8,0(r6)
        stw r8,4(r6)
        addi r6,r6,8

L(zero_word_small):
        bf 29,L(zero_half_small)
        stw r8,0(r6)
        addi r6,r6,4

L(zero_half_small):
        bf 30,L(zero_byte_small)
        sth r8,0(r6)
        addi r6,r6,2

L(zero_byte_small):
        bf 31,L(finish)
        stb r8,0(r6)

        blr

END (bzero)
libc_hidden_builtin_def (bzero)
