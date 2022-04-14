#define _GNU_SOURCE
#include <string.h>

#if !defined(strdupa) && !defined(__GNUC__)
 #error strdupa not defined as a macro
#endif

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

int main()
{
	char *s = "hi";
	char *dup = strdupa(s);
	assert(dup != s);
	assert(!strcmp(dup, s));

	// the argument is evaluated once
	int i = 0;
	strdupa( (i++, "test") );
	assert(i == 1);

#define NO 50
	char *ps[NO];
	for (int i = 0; i < NO; i++)
	{
		char buf[16];
		snprintf(buf, sizeof(buf), "%d", i);
		ps[i] = strdupa(buf);
	}
	for (int i = 0; i < NO; i++)
	{
		int no = atoi(ps[i]);
		assert(no == i);
	}

	return 0;
}
