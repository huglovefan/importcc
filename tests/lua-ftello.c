// ftello() bug from lua

#include <assert.h>
#include <stdio.h>

int unlink(const char *pathname);

int main(void)
{
	FILE *f = fopen("tmp.txt", "w");
	assert(f);

	assert(ftello(f) == 0);
	fprintf(f, "1");
	// fails on 32-bit if off_t is 64 bits but the function isn't redirected to ftello64
	// (happens if the __REDIRECT macro is ignored and the fallback isn't used)
	assert(ftello(f) == 1);

	fclose(f);
	unlink("tmp.txt");

	return 0;
}
