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

// builtin to support implementing strdupa() using a macro
// this is called like __builtin_strdupa(s, alloca(strlen(s)+1))

char* __builtin_strdupa()(const(char)* s, void* storage)
{
	size_t sz = __builtin_strlen(s)+1;
	__builtin_memcpy(storage, s, sz);
	return cast(char*)storage;
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
public import __gccbuiltins;
