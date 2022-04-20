
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

void sync()
{
	int x;

	x = 0;
	assert(__sync_fetch_and_add(&x, 2) == 0);
	assert(x == 2);

	x = 0;
	assert(__sync_fetch_and_sub(&x, 2) == 0);
	assert(x == -2);

	x = 0;
	assert(__sync_add_and_fetch(&x, 2) == 2);
	assert(x == 2);

	x = 0;
	assert(__sync_sub_and_fetch(&x, 2) == -2);
	assert(x == -2);

	x = 1;
	assert(__sync_bool_compare_and_swap(&x, 1, 2)); // compare success
	assert(x == 2);
	assert(!__sync_bool_compare_and_swap(&x, 98, 99)); // compare failure
	assert(x == 2);

	x = 1;
	assert(__sync_val_compare_and_swap(&x, 1, 2) == 1); // compare success
	assert(x == 2);
	assert(__sync_val_compare_and_swap(&x, 98, 99) == 2); // compare failure
	assert(x == 2);

	__sync_synchronize();

	x = 1;
	assert(__sync_lock_test_and_set(&x, 22) == 1);
	assert(x == 22);
	assert(__sync_lock_test_and_set(&x, 333) == 22);
	assert(x == 333);

	x = 99;
	__sync_lock_release(&x);
	assert(x == 0);
}
// xbps configure snippet
void unused2()
{
	volatile unsigned long val = 1;
	__sync_fetch_and_add(&val, 1);
	__sync_fetch_and_sub(&val, 1);
	__sync_add_and_fetch(&val, 1);
	__sync_sub_and_fetch(&val, 1);
}
// libjansson configure snippet
void unused3()
{
	unsigned long val;
	__sync_bool_compare_and_swap(&val, 0, 1);
	__sync_add_and_fetch(&val, 1);
	__sync_sub_and_fetch(&val, 1);
}

void builtin_choose()
{
	int a,b;

	// test with lvalue
	a = b = 0;
	__builtin_choose_expr(1, a, b) = 1;
	assert(a == 1 && b == 0);
	a = b = 0;
	__builtin_choose_expr(0, a, b) = 1;
	assert(a == 0 && b == 1);

	// test return type
	char c;
	assert( sizeof(__builtin_choose_expr(1, c, a) == sizeof(char)) );
	assert( sizeof(__builtin_choose_expr(0, c, a) == sizeof(int)) );

	// test that the losing one isn't evaluated
	a = b = 0;
	__builtin_choose_expr(1, a++, b++);
	assert(a == 1 && b == 0);
	a = b = 0;
	__builtin_choose_expr(0, a++, b++);
	assert(a == 0 && b == 1);
}

int main()
{
	atomics();
	sync();
	builtin_choose();
	return 0;
}
