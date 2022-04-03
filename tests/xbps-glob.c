// if "__USE_FILE_OFFSET64" is set, the glob header uses __REDIRECT_NTH without
//  checking that it's supported

#define _FILE_OFFSET_BITS 64

#include <glob.h>

// this is what it checks to use it (so check it here too)
#if !defined(__USE_FILE_OFFSET64)
 #error expected __USE_FILE_OFFSET64 to be defined
#endif

// these are the affected functions
void *p1 = &glob;
void *p2 = &globfree;
