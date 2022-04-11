module __gccbuiltins;

nothrow @nogc:

// -----------------------------------------------------------------------------

// 6.55 Built-in Functions for Memory Model Aware Atomic Operations

// https://gcc.gnu.org/onlinedocs/gcc/_005f_005fatomic-Builtins.html

enum int __ATOMIC_RELAXED = 0;
enum int __ATOMIC_CONSUME = 1; // same as __ATOMIC_ACQUIRE
enum int __ATOMIC_ACQUIRE = 2;
enum int __ATOMIC_RELEASE = 3;
enum int __ATOMIC_ACQ_REL = 4;
enum int __ATOMIC_SEQ_CST = 5;

type __atomic_load_n(type)(type* ptr, int memorder)
if (__traits(isIntegral, type) || is(immutable type : immutable void*))
{
	import core.atomic;

	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return atomicLoad!(MemoryOrder.raw)(*ptr);
		case __ATOMIC_SEQ_CST: return atomicLoad!(MemoryOrder.seq)(*ptr);
		case __ATOMIC_ACQUIRE: return atomicLoad!(MemoryOrder.acq)(*ptr);
		case __ATOMIC_CONSUME: goto case __ATOMIC_ACQUIRE;
	}
}

void __atomic_store_n(type)(type* ptr, type val, int memorder)
if (__traits(isIntegral, type) || is(immutable type : immutable void*))
{
	import core.atomic;

	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return atomicStore!(MemoryOrder.raw)(*ptr, val);
		case __ATOMIC_SEQ_CST: return atomicStore!(MemoryOrder.seq)(*ptr, val);
		case __ATOMIC_RELEASE: return atomicStore!(MemoryOrder.rel)(*ptr, val);
	}
}

type __atomic_add_fetch(type)(type* ptr, type val, int memorder)
if (__traits(isIntegral, type))
{
	import core.atomic;

	static if (!__traits(isUnsigned, type))
		assert(val >= 0); // casted to size_t, must be positive

	// returns the new value
	// note: usage with pointer arguments not implemented (must not scale by type size)
	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return atomicFetchAdd!(MemoryOrder.raw)    (*ptr, val)+val;
		case __ATOMIC_CONSUME: goto case __ATOMIC_ACQUIRE;
		case __ATOMIC_ACQUIRE: return atomicFetchAdd!(MemoryOrder.acq)    (*ptr, val)+val;
		case __ATOMIC_RELEASE: return atomicFetchAdd!(MemoryOrder.rel)    (*ptr, val)+val;
		case __ATOMIC_ACQ_REL: return atomicFetchAdd!(MemoryOrder.acq_rel)(*ptr, val)+val;
		case __ATOMIC_SEQ_CST: return atomicFetchAdd!(MemoryOrder.seq)    (*ptr, val)+val;
	}
}

type __atomic_sub_fetch(type)(type* ptr, type val, int memorder)
if (__traits(isIntegral, type))
{
	import core.atomic;

	static if (!__traits(isUnsigned, type))
		assert(val >= 0); // casted to size_t, must be positive

	// returns the new value
	// note: usage with pointer arguments not implemented (must not scale by type size)
	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return atomicFetchSub!(MemoryOrder.raw)    (*ptr, val)-val;
		case __ATOMIC_CONSUME: goto case __ATOMIC_ACQUIRE;
		case __ATOMIC_ACQUIRE: return atomicFetchSub!(MemoryOrder.acq)    (*ptr, val)-val;
		case __ATOMIC_RELEASE: return atomicFetchSub!(MemoryOrder.rel)    (*ptr, val)-val;
		case __ATOMIC_ACQ_REL: return atomicFetchSub!(MemoryOrder.acq_rel)(*ptr, val)-val;
		case __ATOMIC_SEQ_CST: return atomicFetchSub!(MemoryOrder.seq)    (*ptr, val)-val;
	}
}

bool __atomic_test_and_set(type)(type* ptr, int memorder)
if (__traits(isIntegral, type) && type.sizeof == 1)
{
	import core.atomic;

	// gcc stores 1, returns true if old value non-zero
	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return !!atomicExchange!(MemoryOrder.raw)    (ptr, type(1));
		case __ATOMIC_CONSUME: goto case __ATOMIC_ACQUIRE;
		case __ATOMIC_ACQUIRE: return !!atomicExchange!(MemoryOrder.acq)    (ptr, type(1));
		case __ATOMIC_RELEASE: return !!atomicExchange!(MemoryOrder.rel)    (ptr, type(1));
		case __ATOMIC_ACQ_REL: return !!atomicExchange!(MemoryOrder.acq_rel)(ptr, type(1));
		case __ATOMIC_SEQ_CST: return !!atomicExchange!(MemoryOrder.seq)    (ptr, type(1));
	}
}

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
