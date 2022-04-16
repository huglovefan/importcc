module __clangbuiltins;

version(D_InlineAsm_X86)    version = asm_x86_any;
version(D_InlineAsm_X86_64) version = asm_x86_any;

nothrow @nogc:

// -----------------------------------------------------------------------------

// https://clang.llvm.org/docs/LanguageExtensions.html#builtin-functions

version(asm_x86_any)
void __builtin_debugtrap()()
{
	asm nothrow @nogc { int 3; }
}
