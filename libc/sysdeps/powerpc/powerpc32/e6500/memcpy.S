#include "ppc-asm.h"
#include <sysdep.h>
#include <bp-sym.h>
#include <bp-asm.h>

	// r3 = destination
	// r4 = source
	// r5 = byte count
	
	// volatile fixed point registers usable:
	// r0, r3-r12

	// volatile floating point registers usable:
	// f0-f13

	.section	".text"
EALIGN (BP_SYM (memcpy), 5, 1)

	cmplw cr0,r4,r3	// if source==destination, return.
	beqlr cr0
	mr r6, r3
	dcbt 0,r4
	dcbtst 0,r3
	
	cmplwi r5,8		// if number of bytes is less than 8 (optimal value TBD), but greater than zero. copy byte-by-byte
	blt Lcopy_bytes
	
	neg r0,r4		// temp = r0
	andi. r10,r0,63		// rem = r10
	beq Lsrc_aligned
	andi. r11,r0,3		// count = r11 [temp & 3]
	beq L1
	lwz r12,0(r4)
	subf r5,r11,r5		// n = n - count
	add r4,r4,r11
	stw r12,0(r6)	
	add r6,r6,r11
L1:	
	cmplwi 7,r5,63
#	mr r10,r5		// rem = n
	ble 7,Lset_rem_bytes
				// Distance of source from cache line boundary
	subf. r10,r11,r10	// rem = rem - count;
	beq 0,Lsrc_aligned
	srwi r11,r10,2		// count = rem / sizeof(unsigned long);
	subf r5,r10,r5		// n = n - rem;
	addi r4,r4,-4
	addi r6,r6,-4
	mtctr r11
L2:
	lwzu 0,4(r4)
	stwu 0,4(r6)
	bdnz L2
	addi r6,r6,4
	addi r4,r4,4
Lsrc_aligned:
	srwi. r11,r5,6		//count = n / CACHE_LINE_SIZE;
	rlwinm r10,r5,0,26,31	//rem = n % CACHE_LINE_SIZE;
	beq 0,Ladjust_srcdest_p
	rlwinm. r7,r6,3,26,28	//shift = ((uintptr_t)p_d_ul & (sizeof(double) - 1)) * 8;
	cmplwi 7,r11,256	//while (count > (L1_CACHE_SIZE/2)/CACHE_LINE_SIZE) {
	bne 0,L3
	ble 7, L4
	addi r7,r11,-256
#ifdef _SOFT_FLOAT
	addi r6, r6, -4
	addi r4, r4, -4
#else
	addi r6, r6, -8
	addi r4, r4, -8
#endif	

#ifdef SHARED
	mflr r0
/* Establishes GOT addressability so we can load __cache_line_size
   from static. This value was set from the aux vector during startup.  */
	SETUP_GOT_ACCESS(r9,got_label_1)
	addis r9,r9,__cache_line_size-got_label_1@ha
	lwz r9,__cache_line_size-got_label_1@l(r9)
	mtlr r0
#else
/* Load __cache_line_size from static. This value was set from the
   aux vector during startup.  */
	lis r9,__cache_line_size@ha
	lwz r9,__cache_line_size@l(r9)
#endif
	cmplwi 5, r9, 64
	mtctr r7
	bne 5,L5_NoCache
L5:
	mr r12, r6
#ifdef _SOFT_FLOAT
	addi r7,r4,260
	dcbt 0,r7
	addi r7,r6,68
	dcbzl 0,r7
	addi r11,r11,-1
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
#else
	addi r7,r4,264
	dcbt 0,r7
	addi r7,r6,72
	dcbzl 0,r7
	addi r11,r11,-1
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
#endif	
 	dcbf 0,r12
	bdnz L5
L6:
	addi r7,r11,-4
	mtctr r7
L7:	
	addi r11,r11,-1
#ifdef _SOFT_FLOAT
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
#else	
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
#endif	
	bdnz L7
L8:
	addi r7,r11,-1
	mtctr r7
L9:	
#ifdef _SOFT_FLOAT
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
#else
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
#endif	
	bdnz L9
L10:
#ifdef _SOFT_FLOAT
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
	
#else
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
	addi r4,r4,4
	addi r6,r6,4
#endif	
	b Lcopy_remaining
L3:	
	addi r6,r6,-4
	addi r4,r4,-4
	ble- 7,L17
	addi r7,r11,-256
	mtctr r7
#ifdef SHARED
	mflr    r0
/* Establishes GOT addressability so we can load __cache_line_size
   from static. This value was set from the aux vector during startup.  */
        SETUP_GOT_ACCESS(r9,got_label_2)
        addis r9,r9,__cache_line_size-got_label_2@ha
        lwz r9,__cache_line_size-got_label_2@l(r9)
        mtlr r0
#else
/* Load __cache_line_size from static. This value was set from the
   aux vector during startup.  */
	lis r9,__cache_line_size@ha
	lwz r9,__cache_line_size@l(r9)
#endif
	cmplwi 5, r9, 64
	mtctr r7
	bne 5,L11_NoCache	
L11:
	mr r12, r6
	addi r7,r4,260
	dcbt 0,r7
	addi r7,r6,68
	dcbzl 0,r7
	addi r11,r11,-1
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
	dcbf 0, r12
	bdnz L11
L12:
	addi r7,r11,-4
	mtctr r7
	.p2align 4,,15
L13:
	addi r11,r11,-1
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
	bdnz L13
L14:
	addi r7,r11,-1
	mtctr r7
L15:
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
	bdnz L15
L16:
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
	b Lcopy_remaining
L4:
	cmplwi 7,r11,4
#ifdef _SOFT_FLOAT
	addi r6, r6, -4
	addi r4, r4, -4
#else
	addi r6, r6, -8
	addi r4, r4, -8
#endif	
	bgt 7,L6
	cmpwi 7,r11,1
	beq 7,L10
	b L8
L17:
	cmplwi 7,r11,4
	bgt 7, L12
	cmpwi 7, r11,1
	beq 7,L16
	b L14

Lset_rem_bytes:
	mr r10,r5		// rem = n
Ladjust_srcdest_p:
	addi r6, r6, -4
	addi r4, r4, -4
Lcopy_remaining:
	srwi.  r11,r10,3	// count = rem / sizeof(unsigned long);
	rlwinm r5,r10,0,29,31	// n =  rem = rem % sizeof(unsigned long);
	beq 0, Ladjust_copy_bytes
	mtcrf   0x01,r11
	
	bf cr7*4+1,16f
	lwzu r7,4(r4) 		/* copy 32 byte  */
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	lwzu r8,4(r4)
	stwu r9,4(r6)
	stwu r7,4(r6)
	stwu r8,4(r6)
16:
	bf cr7*4+2,8f 		/* copy 16 byte  */
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
	
8:
	bf cr7*4+3,Ladjust_copy_bytes 	/* copy 8 bytes  */
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	
Ladjust_copy_bytes:
	addi r4,r4,4
	addi r6,r6,4
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
	.p2align 4,,15
1:
	addi r0,r5,-4		// 5, 6, 7 bytes
	lwz r9,0(r4)
	lwzx r11,r4,r0
	stw r9,0(r6)
	stwx r11,r6,r0
	blr
	.p2align 4,,15
2:
	// 0 or 1 bytes
	mtocrf 0x1,r5		// nbytes == 0 ? return
	bflr 31
	lbz r0,0(r4)		// nbytes == 1
	stb r0,0(r6)
	blr	
	
L5_NoCache:
	addi r11,r11,-1
#ifdef _SOFT_FLOAT
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
#else	
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
	lfdu f0,8(r4)
	lfdu f1,8(r4)
	lfdu f2,8(r4)
	lfdu f3,8(r4)
	stfdu f0,8(r6)
	stfdu f1,8(r6)
	stfdu f2,8(r6)
	stfdu f3,8(r6)
#endif	
	bdnz L5_NoCache
	b L6

L11_NoCache:
	addi r11,r11,-1
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	stwu r8,4(r6)
	stwu r9,4(r6)
	lwzu r7,4(r4)
	lwzu r8,4(r4)
	lwzu r9,4(r4)
	stwu r7,4(r6)
	lwzu r7,4(r4)
	stwu r8,4(r6)
	stwu r9,4(r6)
	stwu r7,4(r6)
	bdnz L11_NoCache
	b L12

END (BP_SYM (memcpy))
libc_hidden_builtin_def (memcpy)
