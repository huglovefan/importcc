// basic use of stdarg
// this requires druntime to be linked in
#include <stdarg.h>
int sum(int cnt, ...)
{
	va_list ap;
	va_start(ap, cnt);
	int rv = 0;
	for (int i = 0; i < cnt; i++)
		rv += va_arg(ap, int);
	va_end(ap);
	return rv;
}
void abort(void);
int main()
{
	int v = sum(4, 1,3,5,7);
	if (v != 1+3+5+7) abort();
	return 0;
}
