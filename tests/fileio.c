// test some functions that use off_t

#include <assert.h>
#include <dirent.h>
#include <stdio.h>

int main(void)
{
	FILE *f = fopen("tmp.txt", "w");
	assert(f);
	assert(ftell(f) == 0); // long
	assert(ftello(f) == 0); // off_t
	fprintf(f, "1");
	assert(ftell(f) == 1); // long
	assert(ftello(f) == 1); // off_t

	// 32-bit off_t max
	fseeko(f, 0x7fffffff, SEEK_SET);
	assert(ftello(f) == 0x7fffffff);

	if (sizeof(off_t) == 4)
	{
#if defined(_FILE_OFFSET_BITS) && _FILE_OFFSET_BITS == 64
		assert(0);
#endif
	}
	else if (sizeof(off_t) == 8)
	{
#if defined(_FILE_OFFSET_BITS) && _FILE_OFFSET_BITS == 32
		assert(0);
#endif
		// overflow 32-bit one by 1
		fseeko(f, 0x80000000, SEEK_SET);
		assert(ftello(f) == 0x80000000);

		// 64-bit off_t max
		fseeko(f, 0x7fffffffffffffffLL, SEEK_SET);
		assert(ftello(f) == 0x7fffffffffffffffLL);
	}
	else
		assert(0);

	return 0;
}
