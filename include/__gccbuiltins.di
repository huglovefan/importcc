module __gccbuiltins;

nothrow @nogc:

// -----------------------------------------------------------------------------

// 6.56 Built-in Functions to Perform Arithmetic with Overflow Checking

// https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

// not implemented: any of the generic ones taking 3 different types

private bool __builtin_add_overflow(type)(type a, type b, type* res)
if (__traits(isIntegral, type))
{
	import core.checkedint;
	bool overflow;
	static if (__traits(isUnsigned, type))
		*res = addu(a, b, overflow);
	else
		*res = adds(a, b, overflow);
	return overflow;
}

private bool __builtin_sub_overflow(type)(type a, type b, type* res)
if (__traits(isIntegral, type))
{
	import core.checkedint;
	bool overflow;
	static if (__traits(isUnsigned, type))
		*res = subu(a, b, overflow);
	else
		*res = subs(a, b, overflow);
	return overflow;
}

private bool __builtin_mul_overflow(type)(type a, type b, type* res)
if (__traits(isIntegral, type))
{
	import core.checkedint;
	bool overflow;
	static if (__traits(isUnsigned, type))
		*res = mulu(a, b, overflow);
	else
		*res = muls(a, b, overflow);
	return overflow;
}

alias __builtin_sadd_overflow() = __builtin_add_overflow!int;
alias __builtin_ssub_overflow() = __builtin_sub_overflow!int;
alias __builtin_smul_overflow() = __builtin_mul_overflow!int;

alias __builtin_saddl_overflow() = __builtin_add_overflow!(imported!"core.stdc.config".c_long);
alias __builtin_ssubl_overflow() = __builtin_sub_overflow!(imported!"core.stdc.config".c_long);
alias __builtin_smull_overflow() = __builtin_mul_overflow!(imported!"core.stdc.config".c_long);

alias __builtin_saddll_overflow() = __builtin_add_overflow!long;
alias __builtin_ssubll_overflow() = __builtin_sub_overflow!long;
alias __builtin_smulll_overflow() = __builtin_mul_overflow!long;

alias __builtin_uadd_overflow() = __builtin_add_overflow!uint;
alias __builtin_usub_overflow() = __builtin_sub_overflow!uint;
alias __builtin_umul_overflow() = __builtin_mul_overflow!uint;

alias __builtin_uaddl_overflow() = __builtin_add_overflow!(imported!"core.stdc.config".c_ulong);
alias __builtin_usubl_overflow() = __builtin_sub_overflow!(imported!"core.stdc.config".c_ulong);
alias __builtin_umull_overflow() = __builtin_mul_overflow!(imported!"core.stdc.config".c_ulong);

alias __builtin_uaddll_overflow() = __builtin_add_overflow!ulong;
alias __builtin_usubll_overflow() = __builtin_sub_overflow!ulong;
alias __builtin_umulll_overflow() = __builtin_mul_overflow!ulong;

// -----------------------------------------------------------------------------

// 6.59 Other Built-in Functions Provided by GCC

// https://gcc.gnu.org/onlinedocs/gcc/Other-Builtins.html

alias __builtin_alloca() = imported!"core.stdc.stdlib".alloca;

alias __builtin_memcpy() = imported!"core.stdc.string".memcpy;
alias __builtin_strlen() = imported!"core.stdc.string".strlen;

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
