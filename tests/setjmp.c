#include <setjmp.h>
int printf(char *, ...);
int main()
{
	// https://dlang.org/spec/importc.html#exceptions
	// > setjmp and longjmp are not supported.

	// https://dlang.org/spec/importc.html#volatile
	// > The volatile type-qualifier (C11 6.7.3) is ignored.

	// this requires "volatile" to work properly if -O is used

	volatile int i = 0;

	// uncomment to prevent the optimization that breaks this
	//printf("", &i);

	jmp_buf buf;
	if (setjmp(buf) == 42)
	{
		printf("%d\n", i);
		return 0;
	}
	i++;
	longjmp(buf, 42);
}
