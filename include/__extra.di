module __extra;

// https://issues.dlang.org/show_bug.cgi?id=22767
version(X86_64) alias __va_list_tag = imported!"core.internal.vararg.sysv_x64".__va_list_tag;

nothrow @nogc:

// -----------------------------------------------------------------------------

// __builtin_printf: debug printf to terminal

// bug: name collides with gcc __builtin_printf()

extern(C)
pragma(printf)
void __builtin_printf()(const(char)* fmt, ...)
{
	import core.stdc.stdarg;
	import core.stdc.stdio;

	FILE* f = fopen("/dev/tty", "w");
	if (!f)
		f = stderr;
	if (!f)
		return;

	va_list ap;
	va_start(ap, fmt);

	vfprintf(f, fmt, ap);

	va_end(ap);

	if (f != stderr)
		fclose(f);
}

// -----------------------------------------------------------------------------

// __builtin_dump: pretty-print a value to the terminal

// similar to clang's __builtin_dump_struct
// https://clang.llvm.org/docs/LanguageExtensions.html#builtin-dump-struct

void __builtin_dump(T)(auto ref T t, string name = null)
{
	import core.stdc.stdio;

	FILE* f = fopen("/dev/tty", "w");
	if (!f)
		f = stderr;
	if (!f)
		return;

	if (name)
	{
		fprintf(f, "%s%.*s %.*s = ",
			tagPrefix!T,
			cast(int)T.stringof.length,
			T.stringof.ptr,
			cast(int)name.length,
			name.ptr);
	}

	dump1(f, 0, t);

	if (name)
		fprintf(f, ";");

	fprintf(f, "\n");

	if (f != stderr)
		fclose(f);
}

private const(char)* tagPrefix(T)()
{
	static if (is(T == struct))
		return "struct ";
	else static if (is(T == enum))
		return "enum ";
	else static if (is(T == union))
		return "union ";
	else static if (is(immutable T == immutable void*)) // void pointer
		return "";
	else static if (is(immutable T : immutable void*)) // non-void pointer
		return tagPrefix!(typeof(*T.init));
	else
		return "";
}

/// dump struct
private void dump1(T)(imported!"core.stdc.stdio".FILE* f, int indent, ref T t)
if (is(T == struct))
{
	import core.stdc.stdio;

	fprintf(f, "(struct %.*s) {\n",
		cast(int)T.stringof.length,
		T.stringof.ptr);

	indent++;
	foreach (m; __traits(allMembers, T))
	{
		foreach (i; 0..indent) fprintf(f, "  ");

		fprintf(f, ".%.*s = ",
			cast(int)m.length,
			m.ptr);

		dump1(f, indent, __traits(getMember, t, m));

		fprintf(f, ",\n");
	}
	indent--;

	foreach (i; 0..indent) fprintf(f, "  ");
	fprintf(f, "}");
}

/// dump array
private void dump1(T)(imported!"core.stdc.stdio".FILE* f, int indent, ref T t)
if (__traits(isStaticArray, T))
{
	import core.stdc.stdio;

	// long arrays are printed with each element on its own line
	bool multiline = (t.length > 8);

	fprintf(f, "(%.*s) {",
		cast(int)T.stringof.length,
		T.stringof.ptr);

	if (multiline)
		fprintf(f, "\n");

	indent++;
	foreach (idx; 0..t.length)
	{
		if (multiline)
			foreach (i; 0..indent) fprintf(f, "  ");

		dump1(f, indent, t[idx]);

		if (multiline)
			fprintf(f, ",\n");
		else if (idx != t.length-1)
			fprintf(f, ", ");
	}
	indent--;

	if (multiline)
		foreach (i; 0..indent) fprintf(f, "  ");

	fprintf(f, "}");
}

/// dump arithmetic (int, float, char, enum, bool)
private void dump1(T_)(imported!"core.stdc.stdio".FILE* f, int indent, T_ t)
if (__traits(isArithmetic, T_))
{
	import core.stdc.stdio;

	// the type might have "const" here, remove it so the matching works
	// this can happen with e.g. "const int" inside a struct
	alias Unconst(T : const U, U) = U;
	alias T = Unconst!T_;

	/**/ static if (is(T ==    byte)) fprintf(f, "%hhd", t); // unsigned char
	else static if (is(T ==   ubyte)) fprintf(f, "%hhu", t); // signed char
	else static if (is(T ==   short)) fprintf(f, "%hd", t);
	else static if (is(T ==  ushort)) fprintf(f, "%hu", t);
	else static if (is(T ==     int)) fprintf(f, "%d", t);
	else static if (is(T ==    uint)) fprintf(f, "%u", t);
	else static if (is(T ==    long)) fprintf(f, "%lld", t);
	else static if (is(T ==   ulong)) fprintf(f, "%llu", t);
	else static if (is(T ==   float)) fprintf(f, "%f", t);
	else static if (is(T ==  double)) fprintf(f, "%lf", t);
	else static if (is(T ==    real)) fprintf(f, "%Lf", t); // long double
	else static if (is(T ==    char))
	{
		if (t >= '!' && t <= '~')
			fprintf(f, "'%c'", t);
		else
			fprintf(f, "0x%02hhx", t);
	}
	else static if (is(T X ==  enum))
	{
		fprintf(f, "(enum %.*s) ",
			cast(int)T.stringof.length,
			T.stringof.ptr);
		// dump as underlying type
		dump1!X(f, indent, t);
	}
	else static if (is(T ==    bool)) // _Bool
	{
		fprintf(f, t ? "true" : "false");
	}
	else static if (is(T ==  cfloat)) fprintf(f, "%f%+fi", t.re, t.im);
	else static if (is(T == cdouble)) fprintf(f, "%lf%+lfi", t.re, t.im);
	else static if (is(T ==   creal)) fprintf(f, "%Lf%+Lfi", t.re, t.im);
	else static if (is(T ==  ifloat)) fprintf(f, "%+fi", t);
	else static if (is(T == idouble)) fprintf(f, "%+lfi", t);
	else static if (is(T ==   ireal)) fprintf(f, "%+Lfi", t);
	else static assert(0, "unknown arithmetic type "~T.stringof);
}

/// dump pointer
private void dump1(T)(imported!"core.stdc.stdio".FILE* f, int indent, T t)
if (is(immutable T : immutable void*))
{
	import core.stdc.stdio;

	fprintf(f, "(%s%.*s) ",
		tagPrefix!T,
		cast(int)T.stringof.length,
		T.stringof.ptr);

	if (t)
		fprintf(f, "%p", cast(void*)t);
	else
		fprintf(f, "NULL");
}

/// dump union
private void dump1(T)(imported!"core.stdc.stdio".FILE* f, int indent, ref T t)
if (is(T == union))
{
	import core.stdc.stdio;

	fprintf(f, "(union %.*s) {\n",
		cast(int)T.stringof.length,
		T.stringof.ptr,
		T.sizeof);

	indent++;
	foreach (m; __traits(allMembers, T))
	{
		foreach (i; 0..indent) fprintf(f, "  ");

		fprintf(f, ".%.*s = ",
			cast(int)m.length,
			m.ptr);

		// print just ones that fit on a single line
		// most of them might be garbage so try not to waste space
		static if (
			__traits(isArithmetic, __traits(getMember, t, m)) ||
			is(immutable typeof(__traits(getMember, t, m)) : immutable void*))
		{
			dump1(f, indent, __traits(getMember, t, m));
		}
		else
		{
			fprintf(f, "(%s%.*s) /* %zu bytes */",
				tagPrefix!(typeof(__traits(getMember, t, m)))(),
				cast(int)typeof(__traits(getMember, t, m)).stringof.length,
				typeof(__traits(getMember, t, m)).stringof.ptr,
				typeof(__traits(getMember, t, m)).sizeof);
		}

		fprintf(f, ",\n");
	}
	indent--;

	foreach (i; 0..indent) fprintf(f, "  ");
	fprintf(f, "}");
}
