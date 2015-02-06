#ifndef _E500MC_MATH_PRIVATE_H_
#define _E500MC_MATH_PRIVATE_H_ 1
/* E500MC core FPU does not implement
   fsqrt */

#define __CPU_HAS_FSQRT 0
#include_next <math_private.h>

#endif /* _E500MC_MATH_PRIVATE_H_ */
