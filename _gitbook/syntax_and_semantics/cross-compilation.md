# Cross-compilation

Crystal supports a basic form of [cross compilation](http://en.wikipedia.org/wiki/Cross_compiler).

In order to achieve this, the compiler executable provides two flags:

* `--cross-compile`: When given enables cross compilation mode
* `--target`: the [LLVM Target Triple](http://llvm.org/docs/LangRef.html#target-triple) to use and set the default [compile-time flags](compile_time_flags.html) from

To get the `--target` flags you can execute `llvm-config --host-target` using an installed LLVM 3.5. For example on a Linux it could say "x86_64-unknown-linux-gnu".

If you need to set any compile-time flags not set implicitly through `--target`, you can use the `-D` command line flag.

Using these two, we can compile a program in a Mac that will run on that Linux like this:

```bash
crystal compile your_program.cr --cross-compile --target "x86_64-unknown-linux-gnu"
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
