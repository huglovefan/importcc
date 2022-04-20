module __gccbuiltins;

alias Atomic     = imported!"core.atomic";
alias BitOp      = imported!"core.bitop";
alias CheckedInt = imported!"core.checkedint";

alias c_long = imported!"core.stdc.config".c_long;
alias c_ulong = imported!"core.stdc.config".c_ulong;

alias MemoryOrder = imported!"core.atomic".MemoryOrder;

nothrow @nogc:

// -----------------------------------------------------------------------------

// 6.54 Legacy __sync Built-in Functions for Atomic Memory Access

// https://gcc.gnu.org/onlinedocs/gcc/_005f_005fsync-Builtins.html

// not implemented: arithmetic with pointer argument (must not scale by type size)

type __sync_fetch_and_add(type, T...)(type* ptr, type value, T)
if (__traits(isIntegral, type) /*|| is(immutable type : immutable void*)*/)
{
	return Atomic.atomicFetchAdd(*ptr, value);
}

type __sync_fetch_and_sub(type, T...)(type* ptr, type value, T)
if (__traits(isIntegral, type) /*|| is(immutable type : immutable void*)*/)
{
	return Atomic.atomicFetchSub(*ptr, value);
}

type __sync_add_and_fetch(type, T...)(type* ptr, type value, T)
if (__traits(isIntegral, type) /*|| is(immutable type : immutable void*)*/)
{
	return Atomic.atomicFetchAdd(*ptr, value)+value;
}

type __sync_sub_and_fetch(type, T...)(type* ptr, type value, T)
if (__traits(isIntegral, type) /*|| is(immutable type : immutable void*)*/)
{
	return Atomic.atomicFetchSub(*ptr, value)-value;
}

bool __sync_bool_compare_and_swap(type, T...)(type* ptr, type oldval, type newval, T)
{
	return Atomic.cas(ptr, oldval, newval);
}

type __sync_val_compare_and_swap(type, T...)(type* ptr, type oldval, type newval, T)
if (__traits(isIntegral, type) || is(immutable type : immutable void*))
{
	Atomic.cas(ptr, &oldval, newval);
	return oldval;
}
// hack
c_ulong __sync_val_compare_and_swap(type, T...)(type* ptr, c_ulong oldval, c_ulong newval, T)
if (is(immutable type : immutable void*))
{
	Atomic.cas(ptr, cast(type*)&oldval, cast(type)newval);
	return oldval;
}

void __sync_synchronize(T...)(T)
{
	Atomic.atomicFence();
}

type __sync_lock_test_and_set(type, T...)(type* ptr, type value, T)
{
	return Atomic.atomicExchange!(MemoryOrder.acq)(ptr, value);
}

void __sync_lock_release(type, T...)(type* ptr, T)
{
	Atomic.atomicStore!(MemoryOrder.rel)(*ptr, type(0));
}

// -----------------------------------------------------------------------------

// 6.55 Built-in Functions for Memory Model Aware Atomic Operations

// https://gcc.gnu.org/onlinedocs/gcc/_005f_005fatomic-Builtins.html

// not implemented: arithmetic with pointer argument (must not scale by type size)

enum int __ATOMIC_RELAXED = 0;
enum int __ATOMIC_CONSUME = 1; // same as __ATOMIC_ACQUIRE
enum int __ATOMIC_ACQUIRE = 2;
enum int __ATOMIC_RELEASE = 3;
enum int __ATOMIC_ACQ_REL = 4;
enum int __ATOMIC_SEQ_CST = 5;

type __atomic_load_n(type)(type* ptr, int memorder)
if (__traits(isIntegral, type) || is(immutable type : immutable void*))
{
	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return Atomic.atomicLoad!(MemoryOrder.raw)(*ptr);
		case __ATOMIC_SEQ_CST: return Atomic.atomicLoad!(MemoryOrder.seq)(*ptr);
		case __ATOMIC_ACQUIRE: return Atomic.atomicLoad!(MemoryOrder.acq)(*ptr);
		case __ATOMIC_CONSUME: goto case __ATOMIC_ACQUIRE;
	}
}

void __atomic_store_n(type)(type* ptr, type val, int memorder)
if (__traits(isIntegral, type) || is(immutable type : immutable void*))
{
	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return Atomic.atomicStore!(MemoryOrder.raw)(*ptr, val);
		case __ATOMIC_SEQ_CST: return Atomic.atomicStore!(MemoryOrder.seq)(*ptr, val);
		case __ATOMIC_RELEASE: return Atomic.atomicStore!(MemoryOrder.rel)(*ptr, val);
	}
}

type __atomic_add_fetch(type)(type* ptr, type val, int memorder)
if (__traits(isIntegral, type) /*|| is(immutable type : immutable void*)*/)
{
	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return Atomic.atomicFetchAdd!(MemoryOrder.raw)    (*ptr, val)+val;
		case __ATOMIC_CONSUME: goto case __ATOMIC_ACQUIRE;
		case __ATOMIC_ACQUIRE: return Atomic.atomicFetchAdd!(MemoryOrder.acq)    (*ptr, val)+val;
		case __ATOMIC_RELEASE: return Atomic.atomicFetchAdd!(MemoryOrder.rel)    (*ptr, val)+val;
		case __ATOMIC_ACQ_REL: return Atomic.atomicFetchAdd!(MemoryOrder.acq_rel)(*ptr, val)+val;
		case __ATOMIC_SEQ_CST: return Atomic.atomicFetchAdd!(MemoryOrder.seq)    (*ptr, val)+val;
	}
}

type __atomic_sub_fetch(type)(type* ptr, type val, int memorder)
if (__traits(isIntegral, type) /*|| is(immutable type : immutable void*)*/)
{
	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return Atomic.atomicFetchSub!(MemoryOrder.raw)    (*ptr, val)-val;
		case __ATOMIC_CONSUME: goto case __ATOMIC_ACQUIRE;
		case __ATOMIC_ACQUIRE: return Atomic.atomicFetchSub!(MemoryOrder.acq)    (*ptr, val)-val;
		case __ATOMIC_RELEASE: return Atomic.atomicFetchSub!(MemoryOrder.rel)    (*ptr, val)-val;
		case __ATOMIC_ACQ_REL: return Atomic.atomicFetchSub!(MemoryOrder.acq_rel)(*ptr, val)-val;
		case __ATOMIC_SEQ_CST: return Atomic.atomicFetchSub!(MemoryOrder.seq)    (*ptr, val)-val;
	}
}

bool __atomic_test_and_set(type)(type* ptr, int memorder)
if (__traits(isIntegral, type) && type.sizeof == 1)
{
	final switch (memorder)
	{
		case __ATOMIC_RELAXED: return !!Atomic.atomicExchange!(MemoryOrder.raw)    (ptr, type(1));
		case __ATOMIC_CONSUME: goto case __ATOMIC_ACQUIRE;
		case __ATOMIC_ACQUIRE: return !!Atomic.atomicExchange!(MemoryOrder.acq)    (ptr, type(1));
		case __ATOMIC_RELEASE: return !!Atomic.atomicExchange!(MemoryOrder.rel)    (ptr, type(1));
		case __ATOMIC_ACQ_REL: return !!Atomic.atomicExchange!(MemoryOrder.acq_rel)(ptr, type(1));
		case __ATOMIC_SEQ_CST: return !!Atomic.atomicExchange!(MemoryOrder.seq)    (ptr, type(1));
	}
}

// -----------------------------------------------------------------------------

// 6.56 Built-in Functions to Perform Arithmetic with Overflow Checking

// https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

// not implemented: any of the generic ones taking 3 different types

private bool __builtin_add_overflow(type)(type a, type b, type* res)
if (__traits(isIntegral, type))
{
	bool overflow;
	static if (__traits(isUnsigned, type))
		*res = CheckedInt.addu(a, b, overflow);
	else
		*res = CheckedInt.adds(a, b, overflow);
	return overflow;
}

private bool __builtin_sub_overflow(type)(type a, type b, type* res)
if (__traits(isIntegral, type))
{
	bool overflow;
	static if (__traits(isUnsigned, type))
		*res = CheckedInt.subu(a, b, overflow);
	else
		*res = CheckedInt.subs(a, b, overflow);
	return overflow;
}

private bool __builtin_mul_overflow(type)(type a, type b, type* res)
if (__traits(isIntegral, type))
{
	bool overflow;
	static if (__traits(isUnsigned, type))
		*res = CheckedInt.mulu(a, b, overflow);
	else
		*res = CheckedInt.muls(a, b, overflow);
	return overflow;
}

alias __builtin_sadd_overflow() = __builtin_add_overflow!int;
alias __builtin_ssub_overflow() = __builtin_sub_overflow!int;
alias __builtin_smul_overflow() = __builtin_mul_overflow!int;

alias __builtin_saddl_overflow() = __builtin_add_overflow!c_long;
alias __builtin_ssubl_overflow() = __builtin_sub_overflow!c_long;
alias __builtin_smull_overflow() = __builtin_mul_overflow!c_long;

alias __builtin_saddll_overflow() = __builtin_add_overflow!long;
alias __builtin_ssubll_overflow() = __builtin_sub_overflow!long;
alias __builtin_smulll_overflow() = __builtin_mul_overflow!long;

alias __builtin_uadd_overflow() = __builtin_add_overflow!uint;
alias __builtin_usub_overflow() = __builtin_sub_overflow!uint;
alias __builtin_umul_overflow() = __builtin_mul_overflow!uint;

alias __builtin_uaddl_overflow() = __builtin_add_overflow!c_ulong;
alias __builtin_usubl_overflow() = __builtin_sub_overflow!c_ulong;
alias __builtin_umull_overflow() = __builtin_mul_overflow!c_ulong;

alias __builtin_uaddll_overflow() = __builtin_add_overflow!ulong;
alias __builtin_usubll_overflow() = __builtin_sub_overflow!ulong;
alias __builtin_umulll_overflow() = __builtin_mul_overflow!ulong;

// -----------------------------------------------------------------------------

// 6.59 Other Built-in Functions Provided by GCC

// https://gcc.gnu.org/onlinedocs/gcc/Other-Builtins.html

alias __builtin_alloca() = imported!"core.stdc.stdlib".alloca;

alias __builtin_abort() = imported!"core.stdc.stdlib".abort;
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
	// remove the D module name from the string
	enum x = (){
		size_t dotpos = -1;
		foreach_reverse (i, c; func)
		{
			if (c == '.')
			{
				dotpos = i;
				break;
			}
		}
		return dotpos != -1 ? func[dotpos+1..$] : func;
	}();

	return x.ptr;
}

// find first set
private int __builtin_ffs_tpl(type)(type x)
if (__traits(isIntegral, x) && !__traits(isUnsigned, x))
{
	return x ? BitOp.bsf(x)+1 : 0;
}

// count leading zeros
// https://stackoverflow.com/a/34687453
private int __builtin_clz_tpl(type)(type x)
if (__traits(isIntegral, x) && __traits(isUnsigned, x))
{
	return BitOp.bsr(x) ^ (cast(int)x.sizeof*8 - 1);
}

// count trailing zeros
private int __builtin_ctz_tpl(type)(type x)
if (__traits(isIntegral, x) && __traits(isUnsigned, x))
{
	return BitOp.bsf(x);
}

// population count
private int __builtin_popcount_tpl(type)(type x)
if (__traits(isIntegral, x) && __traits(isUnsigned, x))
{
	return BitOp.popcnt(x);
}

// "number of 1-bits in x modulo 2"
private int __builtin_parity_tpl(type)(type x)
if (__traits(isIntegral, x) && !__traits(isUnsigned, x))
{
	return BitOp.popcnt(x) & 1;
}

alias __builtin_ffs()   = __builtin_ffs_tpl!int;
alias __builtin_ffsl()  = __builtin_ffs_tpl!c_long;
alias __builtin_ffsll() = __builtin_ffs_tpl!long;

alias __builtin_clz()   = __builtin_clz_tpl!uint;
alias __builtin_clzl()  = __builtin_clz_tpl!c_ulong;
alias __builtin_clzll() = __builtin_clz_tpl!ulong;

alias __builtin_ctz()   = __builtin_ctz_tpl!uint;
alias __builtin_ctzl()  = __builtin_ctz_tpl!c_ulong;
alias __builtin_ctzll() = __builtin_ctz_tpl!ulong;

alias __builtin_popcount()   = __builtin_popcount_tpl!uint;
alias __builtin_popcountl()  = __builtin_popcount_tpl!c_ulong;
alias __builtin_popcountll() = __builtin_popcount_tpl!ulong;

alias __builtin_parity()   = __builtin_parity_tpl!int;
alias __builtin_parityl()  = __builtin_parity_tpl!c_long;
alias __builtin_parityll() = __builtin_parity_tpl!long;
