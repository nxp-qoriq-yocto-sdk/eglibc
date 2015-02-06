#ifndef _E6500_MATH_PRIVATE_H_
#define _E6500_MATH_PRIVATE_H_ 1
/* E6500 core FPU does not implement
   fsqrt */

#define __CPU_HAS_FSQRT 0
#include_next <math_private.h>

#endif /* _E6500_MATH_PRIVATE_H_ */
