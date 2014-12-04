# Cross-compilation

The compile-time flags can be redefined by compiling your program with `--cross-compile "new flags"`.

For example, if you are on a Mac, the `uname -m -s` command says `Darwin x86_64`. On some linux 64 bits it will say `Linux x86_64`. We can compile a program in a Mac that will run on that Linux like this:

```bash
crystal your_program.cr --cross-compile "Linux x86_64"
```

This will generate a `.bc` (LLVM bitcode) file and will print a line with a command to execute on the system we are trying to cross-compile to. For example:

```bash
llc your_program.bc  -o your_program.s && clang your_program.s -o your_program  -lpcre -lrt -lm -lgc -lunwind
```

You must copy this `.bc` file to that system and execute those commands. Once you do this the executable will be available in that target system.

This procedure is usually done with the compiler itself to port it to new platforms where a compiler is not yet available. Because in order to compile a Crystal compiler we need an older Crystal compiler, the only two ways to generate a compiler for a system where there isn't a compiler yet are:
* We checkout the latest version of the compiler written in Ruby, and from that compiler we compile the next versions until the current one.
* We create a `.bc` file in the target system and from that file we create a compile.

The first alternative is long and cumbersome, while the second one is much easier.

Cross-compiling can be done for other executables, but its main target is the compiler. If Crystal isn't available in some system you can try cross-compiling it there.

**Note:** there currently isn't a way to add more compile-time flags and not do a cross-compile at the same time.
