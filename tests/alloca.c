// test that alloca can be called + works properly
// this requires druntime to be linked in

#include <stdlib.h>
#include <string.h>

void rectest(int depth)
{
	const int len = 4096;
	char *p;

	if (depth) rectest(depth-1);
	{
		p = alloca(len);
		memset(p, (char)depth, len);
		if (depth) rectest(depth-1);
	}
	if (depth) rectest(depth-1);

	int error = 0;
	for (int i = 0; i < len; i++) error |= p[i] ^ (char)depth;
	if (error) abort();
}

int main()
{
	rectest(10);
	return 0;
}
