#define _GNU_SOURCE
#include <string.h>

#if !defined(strdupa) && !defined(__GNUC__)
 #error strdupa not defined as a macro
#endif

#include <assert.h>

int main()
{
	char *s = "hi";
	char *dup = strdupa(s);
	assert(dup != s);
	assert(!strcmp(dup, s));

	// bug: the argument is evaluated twice
	int i = 0;
	strdupa( (i++, "test") );
#if defined(__GNUC__)
	assert(i == 1);
#else
	assert(i == 2);
#endif

	return 0;
}
