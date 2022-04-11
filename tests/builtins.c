
// gcc tests/builtins.c && ./a.out

// importcc -run tests/builtins.c

#include <assert.h>
int printf(char *, ...);

void atomics()
{
	void *voidp;
	int myint;
	int old;

	voidp = __atomic_load_n(&voidp, 0);
	myint = __atomic_load_n(&myint, 0);

	__atomic_store_n(&voidp, (void *)0, 0); // needs the cast with dmd
	__atomic_store_n(&myint, 0, 0);

	myint = 0;
	assert(__atomic_add_fetch(&myint, 1, 0) == 1);
	assert(myint == 1);
	assert(__atomic_sub_fetch(&myint, 1, 0) == 0);
	assert(myint == 0);

	char          xchar = 123;
	unsigned char uchar = 234;
	signed char   schar = -42;
	_Bool         xbool = 1;
	assert(__atomic_test_and_set(&xchar, 0) == 1);
	assert(__atomic_test_and_set(&uchar, 0) == 1);
	assert(__atomic_test_and_set(&schar, 0) == 1);
	assert(__atomic_test_and_set(&xbool, 0) == 1);
	assert(xchar == 1);
	assert(uchar == 1);
	assert(schar == 1);
	assert(xbool == 1);
	xchar = 0;
	uchar = 0;
	schar = 0;
	xbool = 0;
	assert(__atomic_test_and_set(&xchar, 0) == 0);
	assert(__atomic_test_and_set(&uchar, 0) == 0);
	assert(__atomic_test_and_set(&schar, 0) == 0);
	assert(__atomic_test_and_set(&xbool, 0) == 0);
	assert(xchar == 1);
	assert(uchar == 1);
	assert(schar == 1);
	assert(xbool == 1);
}
// libjansson configure snippet
int unused1()
{
	char l;
	unsigned long v;
	__atomic_test_and_set(&l, __ATOMIC_RELAXED);
	__atomic_store_n(&v, 1, __ATOMIC_RELEASE);
	__atomic_load_n(&v, __ATOMIC_ACQUIRE);
	__atomic_add_fetch(&v, 1, __ATOMIC_ACQUIRE);
	__atomic_sub_fetch(&v, 1, __ATOMIC_RELEASE);
	return 0;
}

int main()
{
	atomics();
	return 0;
}
