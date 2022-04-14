wrapper script for using D's [importC](https://dlang.org/spec/importc.html)
feature as a C compiler

it tries to work as a drop-in replacement for gcc while using dmd to compile
(and `cpp` to preprocess C sources first)

<sup>note: currently requires a patched dmd with the fix for [issue 23011](https://issues.dlang.org/show_bug.cgi?id=23011)</sup>
