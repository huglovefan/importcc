module __gccbuiltins;

nothrow @nogc:

// -----------------------------------------------------------------------------

// 6.56 Built-in Functions to Perform Arithmetic with Overflow Checking

// https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

bool __builtin_uadd_overflow()(uint a, uint b, uint* res)
{
	static import core.checkedint;
	bool overflow;
	*res = core.checkedint.addu(a, b, overflow);
	return overflow;
}

bool __builtin_umul_overflow()(uint a, uint b, uint* res)
{
	static import core.checkedint;
	bool overflow;
	*res = core.checkedint.mulu(a, b, overflow);
	return overflow;
}

bool __builtin_uaddll_overflow()(ulong a, ulong b, ulong* res)
{
	static import core.checkedint;
	bool overflow;
	*res = core.checkedint.addu(a, b, overflow);
	return overflow;
}

bool __builtin_umulll_overflow()(ulong a, ulong b, ulong* res)
{
	static import core.checkedint;
	bool overflow;
	*res = core.checkedint.mulu(a, b, overflow);
	return overflow;
}

// -----------------------------------------------------------------------------

// 6.59 Other Built-in Functions Provided by GCC

// https://gcc.gnu.org/onlinedocs/gcc/Other-Builtins.html

alias __builtin_isgreater()      = imported!"core.stdc.math".isgreater;
alias __builtin_isgreaterequal() = imported!"core.stdc.math".isgreaterequal;
alias __builtin_isless()         = imported!"core.stdc.math".isless;
alias __builtin_islessequal()    = imported!"core.stdc.math".islessequal;
alias __builtin_islessgreater()  = imported!"core.stdc.math".islessgreater;
alias __builtin_isunordered()    = imported!"core.stdc.math".isunordered;

const(char)* __builtin_FUNCTION(string func = __FUNCTION__)()
{
	return func.ptr;
}
