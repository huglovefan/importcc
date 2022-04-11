module __gccbuiltins;

nothrow @nogc:

// -----------------------------------------------------------------------------

// math.h uses either __builtin_* for these (with gcc version macros) or
//  fallbacks using gnu statement expressions which importc doesn't support

// define the builtins here and hand-edit code to use them

bool __builtin_isgreater(T)(T x, T y)
{
	return x > y;
}

bool __builtin_isgreaterequal(T)(T x, T y)
{
	return x >= y;
}

bool __builtin_isless(T)(T x, T y)
{
	return x < y;
}

bool __builtin_islessequal(T)(T x, T y)
{
	return x <= y;
}

bool __builtin_islessgreater(T)(T x, T y)
{
	return !__builtin_isunordered(x, y) && x != y;
}

bool __builtin_isunordered(T)(T x, T y)
{
	return x != y && (x != x || y != y);
}

// -----------------------------------------------------------------------------

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

const(char)* __builtin_FUNCTION(string func = __FUNCTION__)()
{
	return func.ptr;
}
