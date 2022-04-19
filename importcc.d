module importcc;

import core.stdc.stdlib : abort, exit;
import core.sys.posix.stdlib : unsetenv;
import core.sys.posix.unistd : getpid, getppid, isatty;
import core.time;
import etc.c.zlib : crc32_z;
import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;
static import std.ascii;

extern(C) char* strsignal(int sig) nothrow @nogc; // glibc

/+

environment variables:

IMPCC_MAYSKIP='file1.c file2.c'	compile with gcc if dmd fails
IMPCC_OPTNONE=1					ignore -O flags
IMPCC_SKIP='file1.c file2.c'	compile with gcc always
IMPCC_STDERR=$PWD/stderr.log	duplicate all stderr output to file (absolute path)
IMPCC_TTYMSG=1					duplicate error messages to /dev/tty
V=1								print launched subcommands
VV=1							print own command and launched subcommands
DMD=...							override path to dmd executable

IMPCC_FAILCMD=1					print command line on failure
IMPCC_FAILSRC=1					print source code on failure
IMPCC_DUMPDIR=/path				collect preprocessed sources to directory

+/

__gshared:

version = useBuiltinsModule; /// auto-import "import/__importc.di" in preprocessed C sources

bool V     = false;
bool Vself = false;

static immutable DefaultCompiler = "gcc";

enum Mode
{
	compileAndLink,
	compileOnly,
	preprocessOnly,
}
enum ExeType
{
	normal,
	sharedLib,
}
Mode compilerMode;
ExeType exeType;

string outFile;      /// output file path (set by -o)

size_t dmdFileCount; /// number of input files in `dmdArgs`
size_t dmdSourceFileCount; /// ... ones that'll be compiled
size_t dmdLinkerFileCount; /// ... ones that'll be passed to linker

bool doOptimize; /// true if an -O flag was used

bool     doRun;   /// true if -run was used
string[] runArgs; /// arguments for -run command

bool saveTemps;    /// don't delete preprocessed source files
bool preprocessed; /// assume C sources are already preprocessed

string languageOverride; /// language to treat unrecognized input files as ("c" or null)

/// with -c: object files that'll be created (assuming -o wasn't used)
string[] compiledObjects;

/// source files to preprocess before compiling (source path -> temporary file path)
string[string] cppFiles;

/// object files to rename after compiling (old path -> new path)
string[string] objectFilesToRename;

/// preprocessed source files to delete after compiling
string[] junkFiles;

string[] cppArgs = [
	//
	// cpp
	//

	"-w", // no warnings

	//
	// language features
	//

	// char is unsigned in importc
	// this macro is defined when using "gcc -fno-signed-char"
	"-D__CHAR_UNSIGNED__",

	// http://port70.net/~nsz/c/c11/n1570.html#6.10.8.3
	"-D__STDC_NO_ATOMICS__",
	"-D__STDC_NO_VLA__",

	//
	// builtins
	//

	// https://github.com/dlang/druntime/blob/master/src/importc.h
	"-D__IMPORTC__",
	"-D__builtin_offsetof(t,i)=((unsigned long)((char *)&((t *)0)->i - (char *)0))",

	"-D__alignof=_Alignof",
	"-D__alignof__=_Alignof",
	"-D__asm=asm",
	"-D__asm__=asm",
	"-D__attribute=__attribute__",
	"-D__extension__=",
	"-D__inline=inline",
	"-D__inline__=inline",
	"-D__signed=signed",
	"-D__signed__=signed",
	"-D__thread=_Thread_local",
	"-D__volatile__=volatile",

	"-D__float128=__uint128_t", // hack
	"-D__int128_t=__uint128_t", // hack

	"-D__FUNCTION__=__builtin_FUNCTION",
	"-D__PRETTY_FUNCTION__=__builtin_PRETTY_FUNCTION",

	"-Dstrdupa(x)=__builtin_strdupa_finish(__builtin_alloca(__builtin_strdupa_prepare((x))))",

	//
	// glibc
	//

	// undefine gcc version macros
	"-U__GNUC__",
	"-U__GNUC_MINOR__",
	"-U__GNUC_PATCHLEVEL__",

	// glibc's "pragma(mangle)"
	"-D__REDIRECT(name, proto, alias)=name proto asm(#alias)",
	// versions with gcc attributes (leaf, nothrow)
	"-D__REDIRECT_NTH=__REDIRECT",
	"-D__REDIRECT_NTHNL=__REDIRECT",

	// headers that fail to parse
	"-D_ASM_X86_SWAB_H", // unconditionally uses __asm__
	"-D_EMMINTRIN_H_INCLUDED", // unconditionally uses mmx builtins
	"-D_MMINTRIN_H_INCLUDED", // unconditionally uses sse builtins
	"-D_XMMINTRIN_H_INCLUDED", // unconditionally uses sse2 builtins

	// headers that use inline functions (implemented as templates in __importcc.di)
	"-D_BITS_BYTESWAP_H",
	"-D_BITS_UINTN_IDENTITY_H",

	//
	// libraries
	//

	"-DLONG_LONG=long long", // libdumb
	"-DNO_DECLTYPE", // uthash
];

string[] dmdArgs = [
	"-d",                 // no deprecations
	"-fPIC",              // fix warnings on 32-bit (missing from digger dmd.conf)
	"-verrors=context",   // print nice errors like gcc

	// disable typeinfo/etc
	// still need to manually link druntime for a few things
	"-betterC",
	// link in some C builtins used by C code (alloca/va_arg)
	// this is dynamically linked because it's faster (default is static)
	// @@ this uses the system copy with a locally compiled dmd
	"-Xcc=-lphobos2",
];

/// sed script to apply fixes after preprocessing
static immutable string cppSedScript = "";

struct xoutput
{
__gshared:

	static File tty;

	shared static this()
	{
		if ("IMPCC_TTYMSG" in environment)
			opentty();

		uncork();
	}

	static void opentty()
	{
		if (!tty.isOpen &&
			"_IMPCC_XOUTPUT_SKIP_TTY" !in environment &&
			!isatty(2))
		{
			try
				tty = File("/dev/tty", "w");
			catch (Exception)
				{}
		}
	}

	static void write(T...)(T x)
	{
		stderr.write(x);
		if (tty.isOpen)
			tty.write(x);
	}
	static void writeln(T...)(T x)
	{
		stderr.writeln(x);
		if (tty.isOpen)
			tty.writeln(x);
	}
	static void writefln(T...)(T x)
	{
		stderr.writefln(x);
		if (tty.isOpen)
			tty.writefln(x);
	}

	static void cork()
	{
		stderr.setvbuf(128*1024, _IOFBF);
		if (tty.isOpen)
			tty.setvbuf(128*1024, _IOFBF);
	}
	static void uncork()
	{
		stderr.setvbuf(512, _IOLBF);
		if (tty.isOpen)
			tty.setvbuf(512, _IOLBF);
	}

	static void flush()
	{
		stderr.flush();
		if (tty.isOpen)
			tty.flush();
	}
}

int main(string[] args)
out (rv)
{
	if (rv != 0 && "IMPCC_FAILCMD" in environment)
	{
		xoutput.writefln("importcc: the failing command line was:");
		xoutput.writefln("  %s", args);
	}
	if (rv != 0 && "IMPCC_FAILSRC" in environment)
	{
		foreach (arg; args)
		{
			if (!arg.endsWith(".c"))
				continue;

			xoutput.cork();
			xoutput.writeln("=== ", arg, " ===");
			size_t no;
			foreach (line; File(arg, "r").byLine)
				xoutput.writefln("%5d | %s", ++no, line);
			xoutput.uncork();
		}
	}
}
do
{
	if ("V" in environment)
		V = true;
	if ("VV" in environment)
		{ V = true; Vself = true; }

	try
	{
		// with IMPCC_STDERR: re-run the command line in a child process and
		//  duplicate its stderr to the file
		if (auto stderrPath = environment.get("IMPCC_STDERR"))
		{
			environment.remove("IMPCC_STDERR");
			// xoutput won't detect the pipe as a terminal, handle that here
			if (isatty(2))
				environment["_IMPCC_XOUTPUT_SKIP_TTY"] = "1";
			File logFile = File(stderrPath, "a");
			Pipe output = pipe();
			Pid p = spawnProcess(
				args,
				/* stdin  */ stdin,
				/* stdout */ stdout,
				/* stderr */ output.writeEnd
			);
			bool nonempty;
			foreach (line; output.readEnd.byLine)
			{
				stderr.writeln(line);
				logFile.writeln(line);
				nonempty = true;
			}
			// empty line between outputs
			if (nonempty)
				logFile.write('\n');
			output.readEnd.close();
			return p.wait();
		}

		return cliMain(args);
	}
	catch (FriendlyException e)
	{
		xoutput.writeln("importcc: ", e.msg);
		return 1;
	}
	catch (UseAltCompiler e)
	{
		if (e.cause)
			xoutput.writefln("importcc: will use %s to compile %s", e.compiler, e.cause);

		return runCommand(e.compiler~args[1..$]);
	}
	catch (Halt e)
	{
		xoutput.opentty();

		xoutput.writefln("importcc: *** reached halt file %s ***", e.cause);
		xoutput.writefln("importcc: command line: %s", escapeCommand(args));
		xoutput.writefln("importcc: working directory: %s", getcwd());
		xoutput.write('\a');

		xoutput.flush();
		abort();
		return 1;
	}
	catch (Error e)
	{
		xoutput.opentty();
		xoutput.writeln(e);
		xoutput.flush();
		abort();
		return 1;
	}
}

auto myEnforce(T)(T expr, lazy string msg)
{
	enforce!FriendlyException(expr, msg);
}

class FriendlyException : Exception
{
	mixin basicExceptionCtors;
}

/**
 * thrown to request that the command line be re-run with a different compiler
 */
class UseAltCompiler : Throwable
{
	string compiler = DefaultCompiler;
	string cause;

	this(string path)
	{
		cause = path;
		super(null);
	}
}

/**
 * thrown to halt compilation for debugging
 */
class Halt : Throwable
{
	string cause;

	this(string path)
	{
		cause = path;
		super(null);
	}
}

int cliMain(string[] args)
{
	const string[] origArgs = args;

	if (Vself)
		printCommand(args);

	bool argerror;
	while (args.length > 1)
	{
		size_t used;
		doCommandLineArg(args[1..$], used);
		if (!used)
		{
			argerror = true;
			xoutput.writefln("importcc: unknown option '%s'", args[1]);
			used = 1;
		}
		args = args[used..$];
	}
	if (argerror)
		return 1;

	//
	// preprocess sources
	//
	if (cppFiles.length)
	{
		int rv;
		static if (cppSedScript.length)
		{
			pragma(msg, "note: preprocessing with sed script");
			rv = runCppWithSed();
		}
		else
			rv = runCppNoSed();

		if (rv)
			return rv;
	}

	// if preprocessing only, our work is done
	if (compilerMode == Mode.preprocessOnly)
	{
		myEnforce(cppFiles.length, "no input files given");
		return 0;
	}

	myEnforce(dmdFileCount, "no input files given");

	// at this point: inputs have been preprocessed and we're going to run dmd later
	// copy the preprocessed sources to IMPCC_DUMPDIR=
	foreach (arg; dmdArgs)
	{
		switch (arg.extension)
		{
			case ".c":
				if (!preprocessed) // only with -fpreprocessed
					continue;
				saveDumpFile(arg);
				break;
			case ".i":
				saveDumpFile(arg);
				break;
			default:
				break;
		}
	}

	//
	// add some flags based on variables
	//

	version(useBuiltinsModule)
		dmdArgs ~= ["-I="~thisExePath.dirName~"/include"];

	if (compilerMode == Mode.compileOnly)
	{
		dmdArgs ~= "-c";
	}

	if (doOptimize)
	{
		dmdArgs ~= ["-O", "-inline"];
	}

	string defaultOutFileName()
	{
		if (doRun)
			return "importcc_run_"~thisProcessID().to!string;
		else
			return "a.out";
	}

	//
	// if compiling sources to an executable, temporarily rename the output file
	//  to avoid overwriting something with the object file dmd generates for it
	//
	string tmpOutFile;
	if (compilerMode == Mode.compileAndLink && dmdSourceFileCount)
	{
		if (!outFile)
			outFile = defaultOutFileName();

		tmpOutFile = outFile;
		outFile    = outFile.stripExtension~"_tmp"~.outFile.extension;
	}

	if (outFile)
	{
		myEnforce(compilerMode != Mode.compileOnly || dmdFileCount == 1,
			"can't use -o when compiling more than one object file");

		dmdArgs ~= "-of="~outFile;
	}
	else if (compilerMode == Mode.compileAndLink)
	{
		outFile = defaultOutFileName();

		dmdArgs ~= "-of="~outFile;
	}

	//
	// compile!
	//
	{
		MonoTime start = MonoTime.currTime;

		// set CC= for linking

		if (int rv = runCommand(environment.get("DMD", "dmd")~dmdArgs, ["CC": DefaultCompiler]))
		{
			// print to tty on unusual exit code
			if (rv != 1)
				xoutput.opentty();

			xoutput.writefln("importcc: dmd exited with status %s", rv);

			if (rv != 1)
			{
				if (rv >= -64 && rv <= -1)
					xoutput.writefln("importcc: *** process was killed by signal %s (%s)",
						-rv,
						strsignal(-rv).fromStringz);
				xoutput.writefln("importcc: the command line was: %s", escapeCommand(origArgs));
				xoutput.writefln("importcc: working directory: %s", getcwd());
			}

			// if using -run, make sure to delete the executable's object file
			//  on failure since they're randomly named and might pile up
			// note: check tmpOutFile (set if object file will be created) but
			//  delete outFile since it's the one passed as -of= at this point
			if (doRun && tmpOutFile)
			{
				try
				{
					string exeObjectFile = outFile.setExtension(".o");
					std.file.remove(exeObjectFile);
				}
				catch (Exception)
					{}
			}

			// if one of the input files is in IMPCC_MAYSKIP, re-run the
			//  command line with gcc
			string tryGcc;
			loop: foreach (arg; origArgs)
			{
				switch (arg.extension)
				{
					case ".c":
					case ".h":
						if (arg.exists && checkMaySkipFile(arg))
						{
							tryGcc = arg;
							break loop;
						}
						break;
					default:
						break;
				}
			}
			if (tryGcc)
			{
				xoutput.writefln("importcc: will use %s to compile %s", DefaultCompiler, tryGcc);
				int gccRv = runCommand(DefaultCompiler~origArgs[1..$]);
				if (gccRv == 0)
				{
					// clean up temporary files on success
					foreach (path; junkFiles)
						std.file.remove(path);

					return gccRv;
				}
				else
				{
					xoutput.writefln("importcc: %s exited with status %s", DefaultCompiler, gccRv);
				}
			}

			// try to warn for misplaced arguments (possibly meant to fix the error)
			if (runArgs.length)
				xoutput.writefln("importcc: note: command line to -run contains %s argument(s)", runArgs.length);

			return rv;
		}

		Duration elapsed = MonoTime.currTime - start;

		if (elapsed >= 2.seconds)
		{
			// limit to millisecond precision
			elapsed = msecs(elapsed.total!"msecs");

			if (outFile)
				xoutput.writefln("importcc: warning: compiling %s took %s", outFile.baseName, elapsed);
			else
				xoutput.writefln("importcc: warning: compilation took %s", elapsed);
		}
	}

	// rename back from temporary name
	if (tmpOutFile)
	{
		outFile.rename(tmpOutFile);
		swap(outFile, tmpOutFile);
	}

	// delete preprocessed source files
	if (!saveTemps)
	{
		foreach (path; junkFiles)
			std.file.remove(path);
	}

	switch (compilerMode)
	{
		case Mode.compileAndLink:
			// delete dmd's generated object file for the executable
			// the temporary name is used when we know one will be created
			if (tmpOutFile)
			{
				string exeObjectFile = tmpOutFile.setExtension(".o");
				std.file.remove(exeObjectFile);
			}

			checkUnsupportedFunction([outFile]);

			// run the executable
			if (doRun)
			{
				string arg0 = outFile;
				if (!arg0.canFind('/'))
					arg0 = "./"~arg0;
				int rv = runCommand(arg0~runArgs);
				if (rv)
					xoutput.writefln("importcc: command exited with status %s", rv);
				try
					std.file.remove(outFile);
				catch (FileException e)
					xoutput.writeln(e.msg);
				exit(rv);
			}
			break;

		case Mode.compileOnly:
			checkUnsupportedFunction((outFile) ? [outFile] : compiledObjects);

			// if we compiled some automatically-named objects, rename any whose
			//  name had to be changed
			if (!outFile)
			{
				foreach (oldPath, newPath; objectFilesToRename)
					oldPath.rename(newPath);
			}
			break;

		default:
			assert(0);
	}

	return 0;
}

int runCppNoSed()
{
	if (compilerMode == Mode.preprocessOnly)
	// with -E, all output goes in a single file (stdout or set by -o)
	{
		File output = stdout;
		if (outFile)
		{
			try
				output = File(outFile, "w");
			catch (ErrnoException e)
				myEnforce(false, "failed to open output file: "~e.msg);
		}

		foreach (file, _; cppFiles)
		{
			if (V)
				printCommand("cpp"~cppArgs~file);

			int rv = spawnProcess(
				"cpp"~cppArgs~file,
				/* stdin  */ stdin,
				/* stdout */ output,
				/* stderr */ stderr,
				/* cwd    */ null,
				/* flags  */ Config.retainStdout // closed manually
			).wait();

			if (rv)
			{
				xoutput.writefln("importcc: cpp exited with status %s", rv);
				return 1;
			}
		}
	}
	else
	// no -E, preprocess individual files to be used in compilation
	{
		foreach (file, cppOutFile; cppFiles)
		{
			File output;
			try
				output = File(cppOutFile, "w");
			catch (ErrnoException e)
				myEnforce(false, "failed to open output file: "~e.msg);

			if (V)
				printCommand("cpp"~cppArgs~file);

			int rv = spawnProcess(
				"cpp"~cppArgs~file,
				/* stdin  */ stdin,
				/* stdout */ output,
				/* stderr */ stderr,
				/* cwd    */ null,
				/* flags  */ Config.retainStdout // closed manually
			).wait();
			if (rv)
			{
				xoutput.writefln("importcc: cpp exited with status %s", rv);
				return 1;
			}

			version(useBuiltinsModule)
				output.writeln("__import __importcc;");
		}
	}

	return 0;
}

int runCppWithSed()
{
	if (compilerMode == Mode.preprocessOnly)
	// with -E, all output goes in a single file (stdout or set by -o)
	{
		File output = stdout;
		if (outFile)
		{
			try
				output = File(outFile, "w");
			catch (ErrnoException e)
				myEnforce(false, "failed to open output file: "~e.msg);
		}

		// start sed

		if (V)
			printCommand(["sed", cppSedScript]);

		Pipe sedInput = pipe();
		Pid sed = spawnProcess(
			["sed", cppSedScript],
			sedInput.readEnd,
			output
		);

		// preprocess each file and feed the output to sed

		bool error;

		foreach (file, _; cppFiles)
		{
			if (V)
				printCommand("cpp"~cppArgs~file);

			int rv = spawnProcess(
				"cpp"~cppArgs~file,
				/* stdin  */ stdin,
				/* stdout */ sedInput.writeEnd,
				/* stderr */ stderr,
				/* cwd    */ null,
				/* flags  */ Config.retainStdout // closed manually
			).wait();

			if (rv)
			{
				error = true;
				xoutput.writefln("importcc: cpp exited with status %s", rv);
				break;
			}
		}

		// close pipe and wait for sed to finish

		sedInput.close();
		if (int rv = sed.wait())
		{
			error = true;
			xoutput.writefln("importcc: sed exited with status %s", rv);
		}

		if (error)
			return 1;
	}
	else
	// no -E, preprocess individual files to be used in compilation
	{
		foreach (file, cppOutFile; cppFiles)
		{
			File output;
			try
				output = File(cppOutFile, "w");
			catch (ErrnoException e)
				myEnforce(false, "failed to open output file: "~e.msg);

			// start sed

			Pipe sedInput = pipe();
			Pid sed = spawnProcess(
				["sed", cppSedScript],
				/* stdin  */ sedInput.readEnd,
				/* stdout */ output
			);

			// preprocess file and pass the output to sed

			int rv;
			bool error;

			if (V)
				printCommand("cpp"~cppArgs~file);

			rv = spawnProcess(
				"cpp"~cppArgs~file,
				/* stdin  */ stdin,
				/* stdout */ sedInput.writeEnd,
				/* stderr */ stderr,
				/* cwd    */ null,
				/* flags  */ Config.retainStdout // closed manually
			).wait();
			if (rv)
			{
				error = true;
				xoutput.writefln("importcc: cpp exited with status %s", rv);
			}

			// add junk

			version(useBuiltinsModule)
				sedInput.writeEnd.writeln("__import __importcc;");

			// close the pipe and wait for sed to finish

			sedInput.writeEnd.close();

			rv = sed.wait();
			if (rv)
			{
				error = true;
				xoutput.writefln("importcc: sed exited with status %s", rv);
			}

			if (error)
				return 1;
		}
	}

	return 0;
}

void doCommandLineArg(string[] args, out size_t used)
{
	string getOption()
	{
		if (used < 1) used = 1;
		return args[0];
	}
	string getValue()
	{
		if (used < 2) used = 2;
		myEnforce(args.length >= 2, "missing value for option "~args[0]);
		return args[1];
	}
	string[2] getOptionAndValue()
	{
		if (used < 2) used = 2;
		myEnforce(args.length >= 2, "missing value for option "~args[0]);
		return args[0..2];
	}

	switch (getOption())
	{
		//
		// https://pubs.opengroup.org/onlinepubs/9699919799/utilities/c99.html
		//

		case "-c":
			myEnforce(exeType == ExeType.normal, "can't use -c with -shared");
			myEnforce(compilerMode == Mode.compileAndLink, "more than one of -E or -c given");
			compilerMode = Mode.compileOnly;
			return;
		case "-D":
			cppArgs ~= getOptionAndValue();
			return;
		case "-E":
			myEnforce(exeType == ExeType.normal, "can't use -E with -shared");
			myEnforce(compilerMode == Mode.compileAndLink, "more than one of -E or -c given");
			compilerMode = Mode.preprocessOnly;
			return;
		case "-g":
		case "-ggdb":
			dmdArgs ~= "-g";
			return;
		case "-I":
			cppArgs ~= getOptionAndValue();
			return;
		case "-L":
			dmdArgs ~= "-L-L"~getValue();
			return;
		case "-O0":
			doOptimize = false;
			return;
		case "-O":
		case "-Os":
		case "-O1":
		case "-O2":
		case "-O3":
		case "-Ofast":
			if ("IMPCC_OPTNONE" !in environment)
				doOptimize = true;
			return;
		case "-o":
			myEnforce(!outFile, "more than one output file given");
			outFile = getValue();
			return;
		case "-U":
			cppArgs ~= getOptionAndValue();
			return;

		//
		// common gcc flags
		//

		case "-dumpmachine":
			// @@@ do this properly
			// run gcc with this and other flags (mainly -m)
			writeln("x86_64-linux-gnu");
			exit(0);
			return;
		case "-fPIC":
			return; // already set
		case "-fPIE":
			dmdArgs ~= getOption();
			return;
		case "-fpreprocessed":
			preprocessed = true;
			return;
		case "-m32":
		case "-m64":
			cppArgs ~= getOption();
			dmdArgs ~= getOption();
			return;
		case "-march=native":
			dmdArgs ~= "-mcpu=native";
			return;
		case "-pthread":
			cppArgs ~= getOption();
			dmdArgs ~= "-L-lpthread";
			return;
		case "-save-temps":
			saveTemps = true;
			return;
		case "-shared":
			myEnforce(compilerMode == Mode.compileAndLink, "can't use -shared with -E or -c");
			dmdArgs ~= getOption();
			exeType = ExeType.sharedLib;
			return;
		case "-ansi":
		case "-std=c89":
		case "-std=c99":
		case "-std=c11":
		case "-std=gnu89":
		case "-std=gnu99":
		case "-std=gnu11":
			cppArgs ~= getOption();
			return;
		case "-pedantic":
		case "-W":
		case "-Wall":
		case "-Wcast-align":
		case "-Wcast-qual":
		case "-Wdeclaration-after-statement":
		case "-Wextra":
		case "-Wfloat-equal":
		case "-Wmissing-prototypes":
		case "-Wpedantic":
		case "-Wshadow":
		case "-Wsign-conversion":
		case "-Wsuggest-attribute=noreturn":
		case "-Wunreachable-code":
		case "-Wunused-function":
		case "-Wunused-result":
			dmdArgs.filterAll("-d");
			dmdArgs.filterAll("-w");
			dmdArgs.appendUnique("-wi");
			cppArgs.filterAll("-w"); // -W doesn't override this
			return;
		case "-Werror":
			dmdArgs.filterAll("-d");
			dmdArgs.filterAll("-wi");
			dmdArgs.appendUnique("-w");
			cppArgs.filterAll("-w"); // -W doesn't override this
			return;
		case "-w":
			dmdArgs.appendUnique("-d");
			dmdArgs.filterAll("-wi");
			cppArgs.appendUnique("-w");
			return;
		case "-x":
			languageOverride = getValue();
			myEnforce(languageOverride == "c", "-x: unknown language "~languageOverride);
			return;

		//
		// ignored gcc flags
		//

		case "-fmax-errors=3": // dmd -verrors=3
		case "-fno-omit-frame-pointer": // dmd -gs
		case "-fno-stack-protector":
		case "-fno-strict-aliasing":
		case "-fomit-frame-pointer":
		case "-fstrict-aliasing":
			return;

		//
		// cpp flags also accepted by gcc
		//

		case "-dM": // output defined macros (-E only)
		case "-P":
			cppArgs ~= getOption();
			return;
		case "-A":
		case "-include":
			cppArgs ~= getOptionAndValue();
			return;

		//
		// linker flags
		//

		case "--default-symver":
			dmdArgs ~= "-Xcc=-Wl,"~getOption();
			return;
		case "-rpath":
		case "-soname":
		case "-version-script":
			dmdArgs ~= "-Xcc=-Wl,"~getOption()~','~getValue();
			return;

		//
		// dmd
		//

		case "-run":
			myEnforce(compilerMode == Mode.compileAndLink, "can't use -run with -E or -c");
			myEnforce(exeType == ExeType.normal, "can't use -run with -shared");
			addInputFileArg(getValue());
			doRun = true;
			runArgs = args[2..$];
			used = args.length;
			return;

		default:
			goto next;
	}
	assert(0); // cases must use return, not break
next:

	//
	// posix
	//

	if (getOption().startsWith("-D")) // define macro
	{
		cppArgs ~= getOption();
		return;
	}
	if (getOption().startsWith("-I")) // header include path
	{
		cppArgs ~= getOption();
		return;
	}
	if (getOption().startsWith("-L")) // library search path
	{
		dmdArgs ~= "-L"~getOption();
		return;
	}
	if (getOption().startsWith("-l")) // link library
	{
		dmdArgs ~= "-L"~getOption();
		return;
	}
	if (getOption().startsWith("-U")) // undefine macro
	{
		cppArgs ~= getOption();
		return;
	}

	//
	// gcc
	//

	if (getOption().startsWith("-A")) // preprocessor assertion
	{
		// https://gcc.gnu.org/onlinedocs/cpp/Obsolete-Features.html#Assertions
		cppArgs ~= getOption();
		return;
	}
	if (getOption().startsWith("-fuse-ld=")) // specify linker to use
	{
		dmdArgs ~= "-Xcc="~getOption();
		return;
	}
	if (getOption().startsWith("-Wl,")) // pass flags to linker
	{
		// individual -L= args might get reordered, pass using -Xcc=
		//foreach (part; getOption()["-Wl,".length..$].replace(",", " ").splitter)
		//	dmdArgs ~= "-L"~part;
		dmdArgs ~= "-Xcc="~getOption();
		return;
	}
	if (getOption().startsWith("-Wno-")) // silence specific warning
	{
		return; // ignore
	}

	//
	// importcc
	//

	if (getOption().startsWith("-Xcpp="))
	{
		cppArgs ~= getOption()["-Xcpp=".length..$];
		return;
	}
	if (getOption().startsWith("-Xdmd="))
	{
		dmdArgs ~= getOption()["-Xdmd=".length..$];
		return;
	}

	// unsupported option
	if (getOption().startsWith('-'))
	{
		used = 0;
		return;
	}

	// input file
	string path = getOption();
	checkHaltFile(path);
	checkSkipFile(path);
	addInputFileArg(path);
}

/// append if the array doesn't already have it
void appendUnique(ref string[] arr, string it)
{
	if (!arr.canFind(it))
		arr ~= it;
}

/// remove all instances of item from array
void filterAll(ref string[] arr, string it)
{
	arr = arr.filter!(x => x != it).array;
}

void addInputFileArg(string path)
{
	switch (path.extension)
	{
		// C
		case ".c":
		case ".h":
			if (preprocessed)
				goto case ".i";

			// object files go in the current directory (dmd and gcc agree)
			string preprocessedName = path.baseName.suitableInputFile;
			string outputObjectName = preprocessedName.setExtension(".o");
			string wantedObjectName = path.baseName.setExtension(".o");
			// (with the -c option)
			// if two sources have the same name but a different path, dmd gives
			//  an error (duplicate module name) but gcc seems to prefer the
			//  last one given on the command line

			cppFiles[path]  = preprocessedName;
			dmdArgs        ~= preprocessedName;
			junkFiles      ~= preprocessedName;
			if (outputObjectName != wantedObjectName)
				objectFilesToRename[outputObjectName] = wantedObjectName;

			compiledObjects ~= outputObjectName;

			dmdFileCount++;
			dmdSourceFileCount++;
			break;

		// other sources that don't need preprocessing
		case ".d":
		case ".i":
			dmdArgs ~= path;
			dmdFileCount++;
			dmdSourceFileCount++;
			break;

		// compiled code
		case ".a":
		case ".o":
		case ".so":
			dmdArgs ~= path;
			dmdFileCount++;
			dmdLinkerFileCount++;
			break;

		// need gcc for this
		case ".S":
		case ".s":
			throw new UseAltCompiler(path);

		default:
			// .so with version number
			// pass this using -L= because dmd can't detect it by the extension
			if (path.baseName.canFind(".so."))
			{
				dmdArgs ~= "-L="~path;
				dmdFileCount++;
				dmdLinkerFileCount++;
				break;
			}

			if (languageOverride == "c")
				goto case ".c";

			myEnforce(false, "unrecognized input file "~path);
			break;
	}
}

/**
 * convert the path of a C source file to a similar (but different) one that dmd
 *  would accept as an input file
 * 
 * 1. the name part is mangled to be a valid identifier (used as the module name)
 * 2. the extension is replaced with .i
 */
string suitableInputFile(string path)
{
	string dir = path.dirName;
	string base = path.baseName.stripExtension;

	// (fix "base" if name contains only extension)
	if (!path.extension.length)
		base = "";

	// strip non-alphanumeric characters
	// (cast: work with gdc 10)
	base = base.map!(c => std.ascii.isAlphaNum(c) ? c : cast(dchar)'_').to!string;

	// must not start with a digit (or be empty)
	if (!base.length || std.ascii.isDigit(base[0]))
	{
		base = '_'~base;
	}

	// must not conflict with imported modules
	switch (base)
	{
		case "__builtins":
		case "__clangbuiltins": // importcc
		case "__extra":         // importcc
		case "__gccbuiltins":   // importcc
		case "__importcc":      // importcc
		case "core":
		case "etc":
		case "object":
		case "std":
			base = '_'~base;
			break;
		default:
			break;
	}

	path = dir~'/'~base~".i";

	return path;
}

unittest
{
	assert(suitableInputFile("./test.c") == "./test.i");
	assert(suitableInputFile("./aåb.c") == "./a_b.i");
	assert(suitableInputFile("./123.c") == "./_123.i");
	assert(suitableInputFile("./object.c") == "./_object.i");
	assert(suitableInputFile("./.c") == "./_.i");
}

/**
 * look for and warn about unsupported functions used by an object file or
 * executable
 * 
 * currently this only looks for setjmp()
 */
void checkUnsupportedFunction(string[] objs)
{
	// nothing to do?
	// setjmp() is only a problem if optimizations are enabled
	if (!doOptimize)
		return;

	ProcessPipes proc = pipeProcess(
		"nm"~objs,
		Redirect.stdout
	);

	allNamesLoop:
	foreach (line; proc.stdout.byLine)
	{
		int i;
		thisLineLoop:
		foreach (part; line.splitter)
		{
			// the setjmp line looks like this:
			// "                 U _setjmp"

			if (i == 0)
			{
				if (part != "U")
					continue allNamesLoop;

				i++;
				continue thisLineLoop;
			}

			// remove linked symbol version (like "_setjmp@GLIBC_2.2.5")
			if (compilerMode == Mode.compileAndLink)
			{
				size_t atpos = part.indexOf('@');
				if (atpos != -1)
					part = part[0..atpos];
			}

			// nm -D /lib/x86_64-linux-gnu/libc.so.6 | awk '$3~/jmp/&&$3!~/PRIVATE/{print$3}' | grep -o '^[^@]*'
			switch (part)
			{
				case "_longjmp":
				case "longjmp":
				case "__longjmp_chk":
				case "_setjmp":
				case "setjmp":
				case "siglongjmp":
				case "__sigsetjmp":
					xoutput.writefln("*** importcc warning: %s() may not work correctly with optimization enabled (used by: %s)",
						part,
						(objs.length == 1) ? objs[0].baseName : "unknown");
					break;
				default:
					break;
			}

			continue allNamesLoop;
		}
	}

	proc.pid.wait();
}

void saveDumpFile(string path)
{
	string dir = environment.get("IMPCC_DUMPDIR");
	if (!dir)
		return;

	// open out file, ignore error
	File f;
	try
		f = File(path);
	catch (Exception)
		return;

	// get crc of contents to use as filename
	uint crc;
	foreach (buf; f.byChunk(0xffff))
		crc = crc32_z(crc, buf.ptr, buf.length);

	string dumpName = format("dump%08x.i", crc);
	auto dumpPath = chainPath(dir, dumpName);

	// exit if we've already copied the same file
	if (dumpPath.exists)
		return;

again:
	try
		std.file.copy(path, dumpPath);
	catch (Exception e)
	{
		if (!dir.exists)
		{
			dir.mkdirRecurse();
			goto again;
		}
		throw e;
	}
}

int runCommand(const string[] args, string[string] env = null)
{
	if (V)
		printCommand(args);

	return spawnProcess(args, env).wait();
}

void printCommand(const string[] args)
{
	xoutput.write("+ ", escapeCommand(args), '\n');
}

/// clone of std.process.escapeShellCommand() with nicer output (no unnecessary quoting)
string escapeCommand(const string[] cmd)
{
	static bool shouldEscape(string s)
	{
		if (!s.length)
			return true;
		foreach (c; s)
			switch (c)
			{
				case '0': .. case '9':
				case 'A': .. case 'Z':
				case 'a': .. case 'z':
				case '-':
				case '=':
				case '/':
				case '.':
				case ',':
				case ':':
				case '_':
					continue;
				default:
					return true;
			}
		return false;
	}
	static string escapeArgument(string s)
	{
		return shouldEscape(s) ? s.escapeShellFileName : s;
	}
	return cmd.map!escapeArgument.join(' ');
}

/**
 * check if an input file should be skipped according to IMPCC_SKIP
 */
void checkSkipFile(string inputFile)
{
	foreach (pattern; environment.get("IMPCC_SKIP", "").splitter)
	{
		if (testPath(inputFile, pattern))
			throw new UseAltCompiler(inputFile);
	}
}

/**
 * check if an input file should be compiled with gcc according to IMPCC_MAYSKIP
 */
bool checkMaySkipFile(string inputFile)
{
	foreach (pattern; environment.get("IMPCC_MAYSKIP", "").splitter)
	{
		if (testPath(inputFile, pattern))
			return true;
	}
	return false;
}

/**
 * check if compilation should be halted according to IMPCC_HALT
 */
void checkHaltFile(string inputFile)
{
	foreach (pattern; environment.get("IMPCC_HALT", "").splitter)
	{
		if (testPath(inputFile, pattern))
			throw new Halt(inputFile);
	}
}

bool testPath(string path, string pattern)
{
	if (pattern.endsWith('/'))
	{
		pattern = pattern.asNormalizedPath.array;

		if (pattern == "/")
			return true;

		path = path.asAbsolutePath.asNormalizedPath.array;

		return path.canFind(chainPath("/", pattern~'/')); // prepend + append slash
	}
	else if (pattern.canFind('/'))
	{
		path    = path.asAbsolutePath.asNormalizedPath.array;
		pattern = pattern.asNormalizedPath.array;

		if (path.length < pattern.length)
			return false;
		else if (path.length == pattern.length)
			return path == pattern;
		else
			return path.endsWith(chainPath("/", pattern)); // prepend slash
	}
	else
	{
		return path.baseName == pattern;
	}
}

unittest
{
	string curdir = getcwd().baseName;

	assert(testPath("src/file.c", "file.c"));
	assert(!testPath("src/file.c", "xfile.c"));
	assert(!testPath("src/xfile.c", "file.c"));

	assert(testPath("src/file.c", "src/file.c"));
	assert(!testPath("src/file.c", "xsrc/file.c"));
	assert(!testPath("xsrc/file.c", "src/file.c"));

	assert(testPath("src/file.c", "src/file.c"));
	assert(!testPath("src/file.c", "src/xfile.c"));
	assert(!testPath("src/xfile.c", "src/file.c"));

	assert(!testPath("src/file.c", "other/file.c"));

	assert(testPath("file.c", curdir~"/file.c"));
	assert(!testPath("file.c", "not_"~curdir~"/file.c"));

	assert(testPath("bad/file.c", "bad/"));
	assert(!testPath("badx/file.c", "bad/"));
	assert(!testPath("bad/file.c", "badx/"));
	assert(!testPath("xbad/file.c", "bad/"));
	assert(!testPath("bad/file.c", "xbad/"));
	assert(!testPath("good/file.c", "bad/"));
	assert(testPath("a.c", "/"));
	assert(testPath("a/b.c", "/"));
}
