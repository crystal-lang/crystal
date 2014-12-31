# Cross-compilation

Crystal supports a basic form of [cross compilation](http://en.wikipedia.org/wiki/Cross_compiler).

In order to achieve this, the compiler executable provides two flags:

* `--cross-compile`: the [compile-time flags](compile_time_flags.html) to use
* `--target`: the [LLVM Target Triple](http://llvm.org/docs/LangRef.html#target-triple) to use

To get the `--cross-compile` flags you can execute `uname -m -s` on a unix system. For example, if you are on a Mac, the `uname -m -s` command says "Darwin x86_64". On some linux 64 bits it will say "Linux x86_64".

To get the `--target` flags you can execute `llvm-config --host-target` using an installed LLVM 3.5. For example on a Linux it could say "x86_64-unknown-linux-gnu".

Using these two, we can compile a program in a Mac that will run on that Linux like this:

```bash
crystal build your_program.cr --cross-compile "Linux x86_64" --target "x86_64-unknown-linux-gnu"
```

This will generate a `.o` ([Object file](http://en.wikipedia.org/wiki/Object_file)) and will print a line with a command to execute on the system we are trying to cross-compile to. For example:

```bash
cc your_program.o -o your_program -lpcre -lrt -lm -lgc -lunwind
```

You must copy this `.o` file to that system and execute those commands. Once you do this the executable will be available in that target system.

This procedure is usually done with the compiler itself to port it to new platforms where a compiler is not yet available. Because in order to compile a Crystal compiler we need an older Crystal compiler, the only two ways to generate a compiler for a system where there isn't a compiler yet are:
* We checkout the latest version of the compiler written in Ruby, and from that compiler we compile the next versions until the current one.
* We create a `.o` file in the target system and from that file we create a compile.

The first alternative is long and cumbersome, while the second one is much easier.

Cross-compiling can be done for other executables, but its main target is the compiler. If Crystal isn't available in some system you can try cross-compiling it there.

**Note:** there currently isn't a way to add more compile-time flags and not do a cross-compile at the same time.
