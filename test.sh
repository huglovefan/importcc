if [ ! -e importcc ] || [ importcc.d -nt importcc ]
then
	( set -x; dmd -O -g -inline importcc.d ) || exit
fi

PATH=$PWD:$HOME/work/result/bin:$PATH

ulimit -c 0

mkdir -p tmp
cd tmp || exit

## check what bitnesses the compiler supports and has libraries for
bits=''
nobits=''
for xbits in 64 32
do
	rm -f true
	if importcc -m$xbits ../tests/true.c -o true 2>/dev/null && ./true
	then
		bits="$bits $xbits"
	else
		nobits="$nobits $xbits"
	fi
done
echo "supported bits:" $bits

g_rv=0
mustrun()
{
	if hasbitness "$@"
	then
		$V importcc "$@" -o a.out && ./a.out
		check mustrun "$@"
	else
		for m in $bits
		do
			$V importcc -m$m "$@" -o a.out && ./a.out
			check mustrun -m$m "$@"
		done
		## check just compilation for unsupported bits
		for m in $nobits
		do
			$V importcc -m$m -c "$@"
			check mustcompile "$@"
		done
	fi
}
mustcompile()
{
	if hasbitness "$@"
	then
		$V importcc -c "$@"
		check mustcompile "$@"
	else
		for m in $bits $nobits
		do
			$V importcc -m$m -c "$@"
			check mustcompile "$@"
		done
	fi
}
check()
{
	if rv=$?; [ $rv -ne 0 ]
	then
		name=$1; shift
		>&2 echo "*** test failed: '$name $*' exited with status $rv"
		g_rv=1
	fi
}
hasbitness()
{
	for arg
	do
		case $arg in
		-m64|-m32) return 0;;
		esac
	done
	return 1
}

mustrun     ../tests/true.c

mustrun     ../tests/lua-ftello.c
mustcompile ../tests/xbps-glob.c
mustcompile ../tests/xbps-scandir.c '-D_XOPEN_SOURCE=700' '-D_FILE_OFFSET_BITS=64' -std=c99 -pthread

mustcompile ../tests/includes.c
#mustcompile ../tests/includes.c -D_GNU_SOURCE # importcc default
mustcompile ../tests/includes.c -std=c99
mustcompile ../tests/includes.c -D_FILE_OFFSET_BITS=64

mustrun     ../tests/alloca.c
mustrun     ../tests/fileio.c
mustrun     ../tests/strdupa.c

mustcompile  ../tests/builtin_dump.c

# non-writable source directory
mustcompile /usr/include/stdlib.h

## test that compiling a source file doesn't overwrite other object files
# when compiling and linking an executable with source files given on the command line,
# dmd compiles them to an object file named after the executable
# this could overwrite a different object file used in compilation and cause it to fail
( set -e
	echo 'int main(){return 0;}' >main.c
	echo 'int x;' >other.c
	importcc -c main.c
	rm -f main
	importcc main.o other.c -o main
	./main

	echo 'int y;' > a.c
	echo 'int x;' > b.c
	importcc -c a.c
	importcc a.o b.c -shared ## compiles b.c to a.o after the out file name
) || { g_rv=1; echo error; }

# test that linking with versioned shared objects works
( set -e
	echo 'int x;' > a.c
	echo 'int main(){return 0;}' >main.c
	importcc -shared a.c -o a.so.1
	## versionless one exists
	ln -sf a.so.1 a.so
	importcc main.c a.so.1
	## no versionless one
	rm a.so
	importcc main.c a.so.1
) || { g_rv=1; echo error; }

## test that preprocessing an unknown file extension works with "-x c"
( set -e
	echo '#include <stdio.h>' >abc.def
	importcc -E -x c abc.def | grep printf >/dev/null || exit
) || { g_rv=1; echo error; }

## test setjmp() limitation
## - the test snippet gives a different result with -O vs. without
## - importcc warns if setjmp() is used when compiling with -O
( set -e
	# sanity check: stderr is normally empty
	out=$(importcc -O2 ../tests/true.c 2>&1)
	[ -z "$out" ]
	out=$(importcc -O2 -c ../tests/true.c 2>&1)
	[ -z "$out" ]
	# warns when compiling executable
	out=$(importcc -O2 ../tests/setjmp.c 2>&1)
	[ -n "$out" ]
	# warns when compiling object file
	out=$(importcc -O2 -c ../tests/setjmp.c 2>&1)
	[ -n "$out" ]

	# setjmp.c, optimizations OFF -> 1
	out=$(importcc -O0 -run ../tests/setjmp.c 2>/dev/null)
	[ "$out" = 1 ]

	# setjmp.c, optimizations ON -> 0
	out=$(importcc -O2 -run ../tests/setjmp.c 2>/dev/null)
	[ "$out" = 0 ]
) || { g_rv=1; echo error; }

## test that linking doesn't depend on $CC or cc executable
( set -e
	# $CC
	CC=/bin/false importcc -run ../tests/true.c

	# cc executable
	mkdir -p tmpbin
	echo 'echo fail; false' >tmpbin/cc
	PATH=$PWD/tmpbin:$PATH
	[ "$(cc 2>&1)" = fail ] # check that it's used
	importcc -run ../tests/true.c
) || { g_rv=1; echo error; }

## test that compiling an executable doesn't leave an object file behind
( set -e
	rm -rf xtmp
	mkdir -p xtmp
	cd xtmp

	mkdir src
	cp ../../tests/true.c src/

	importcc                src/true.c && [ -z "$(find -name '*.o')" ]
	importcc           -run src/true.c && [ -z "$(find -name '*.o')" ]
	importcc -o hi          src/true.c && [ -z "$(find -name '*.o')" ]
	importcc -o hi     -run src/true.c && [ -z "$(find -name '*.o')" ]
	importcc -o src/hi      src/true.c && [ -z "$(find -name '*.o')" ]
	importcc -o src/hi -run src/true.c && [ -z "$(find -name '*.o')" ]

	cd ..
	rm -rf xtmp
) || { g_rv=1; echo error; }

if [ $g_rv -eq 0 ]
then
	echo ok
fi

exit $g_rv
