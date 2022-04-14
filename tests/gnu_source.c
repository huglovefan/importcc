
// test that _GNU_SOURCE isn't defined by default (because it can change the
//  behavior of some functions)

#include <assert.h>
#include <string.h>

// strerror_r returns char* with _GNU_SOURCE, int otherwise

int main()
{
	char buf[24] = {0};
	int rv = strerror_r(0, buf, 24);
	assert(rv == 0); // 0 on success
	// ^ this also fails if dmd is affected by https://issues.dlang.org/show_bug.cgi?id=23011
	assert(buf[0] != 0); // non-gnu version always writes to the buffer
	return 0;
}
