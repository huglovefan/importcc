module __importcc;

nothrow @nogc:

// -----------------------------------------------------------------------------

// math.h defines iszero() using a macro with __typeof__ which importc
//  doesn't support

// define the builtin here and hand-edit code to use it

// note: there are two implementations, this assumes __SUPPORT_SNAN__=0
//  (whatever that is)

bool __builtin_iszero(T)(T v)
{
	return v == 0;
}

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

const(char)* __builtin_FUNCTION(string func = __FUNCTION__)()
{
	return func.ptr;
}

// -----------------------------------------------------------------------------

// reimplement some inline functions here to prevent them from polluting object files
// the #include guards for these files have been defined in importcc.d

// /usr/include/x86_64-linux-gnu/bits/byteswap.h

alias __bswap_constant_16 = __builtin_bswap16;
alias __bswap_16          = __builtin_bswap16;

alias __bswap_constant_32 = __builtin_bswap32;
alias __bswap_32          = __builtin_bswap32;

alias __bswap_constant_64 = __builtin_bswap64;
alias __bswap_64          = __builtin_bswap64;

// /usr/include/x86_64-linux-gnu/bits/uintn-identity.h

ushort __uint16_identity()(ushort x)
{
	return x;
}

uint __uint32_identity()(uint x)
{
	return x;
}

ulong __uint64_identity()(ulong x)
{
	return x;
}

// -----------------------------------------------------------------------------

public import __extra;
