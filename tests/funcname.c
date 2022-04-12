#include <assert.h>
#include <string.h>

// gcc: warning for __func__ at top level
// clang: warning for all three at top level
// dmd: error for __func__ at top level, others not supported in C

//const char *topfunc = __func__;
const char *topfunction = __FUNCTION__;
const char *toppretty = __PRETTY_FUNCTION__;

int printf(const char *, ...);

int main()
{
	const char *thisfunc = __func__;
	const char *thisfunction = __FUNCTION__;
	const char *thispretty = __PRETTY_FUNCTION__;

	assert(!strcmp(topfunction, ""));
	assert(!strcmp(toppretty, "top level"));

	assert(!strcmp(thisfunc, "main"));
	assert(!strcmp(thisfunction, "main"));
	// gcc: "main"
	// clang: "int main()"
	assert(strstr(thispretty, "main"));

	const char (*sp)[];

	sp = &__func__;
	// these fail, the functions don't return a reference in importcc
	// you can try to do something with CTFE but i couldn't get it to work
	// (best solution gives "cannot use non-constant CTFE pointer in an initializer")
	//sp = &__FUNCTION__;
	//sp = &__PRETTY_FUNCTION__;

	assert(sizeof(__func__) == strlen(__func__)+1);
	// these fail, they're pointers in importcc
	//assert(sizeof(__FUNCTION__) == strlen(__FUNCTION__)+1);
	//assert(sizeof(__PRETTY_FUNCTION__) == strlen(__PRETTY_FUNCTION__)+1);

	return 0;
}
