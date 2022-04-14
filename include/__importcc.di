module __importcc;

nothrow @nogc:

// -----------------------------------------------------------------------------

// definition in math.h uses GNU extensions and isn't fixable by macros
// hand-edit code to use this

int __builtin_iszero(T)(T v)
if (__traits(isFloating, T))
{
	return v == 0;
}

// -----------------------------------------------------------------------------

// builtin to support implementing strdupa() using a macro
// this is called like __builtin_strdupa_finish(alloca(__builtin_strdupa_prepare(x)))

template __strdupa_tpl()
{
	const(char)[] str; // thread-local

	size_t prepare()(const(char)* s)
	{
		return (str = s[0..__builtin_strlen(s)+1]).length;
	}

	char* finish()(void* p)
	{
		auto s = str;
		__builtin_memcpy(p, s.ptr, s.length);
		return cast(char*)p;
	}
}

alias __builtin_strdupa_prepare() = __strdupa_tpl!().prepare;
alias __builtin_strdupa_finish() = __strdupa_tpl!().finish;

// -----------------------------------------------------------------------------

// similar to __builtin_FUNCTION() but returns "top level" when outside a function

// gcc includes the return type and parameters in this when compiling C++, clang
//  does it for C too

const(char)* __builtin_PRETTY_FUNCTION(string func = __PRETTY_FUNCTION__)()
{
	pragma(inline, true);
	return func.length ? func.ptr : "top level".ptr;
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
