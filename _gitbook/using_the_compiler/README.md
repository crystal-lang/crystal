# Using the compiler

Once you [install](../installation/README.md) the compiler you will have a `crystal` binary at your disposal.

In the next sections a dollar sign (`$`) denotes the command line.

## Compiling and running at once

To compile and run a program in a single shot you can invoke `crystal` with a single filename:

```
$ crystal some_program.cr
```

Crystal files end with the `.cr` extension.

Alternative you can use the `run` command:

```
$ crystal run some_program.cr
```

## Creating an executable

To create an executable use the `build` command:

```
$ crystal build some_program.cr
```

This will create a `some_program` file that you can execute:

```
$ ./some_program
```

**Note:** By default the generated executables **are not fully optimized**. To turn optimizations on, use the `--release` flag:

```
$ crystal build some_program.cr --release
```

Make sure to always use `--release` for production-ready executables and when performing benchmarks.

The reason for this is that performance without full optimizations is still pretty good and provides fast compile times, so you can use the `crystal` command almost as if it were an interpreter.

## Creating a project or library

Use the `init` command to create a Crystal project with the standard directory structure.

```
$ crystal init lib MyCoolLib
      create  MyCoolLib/.gitignore
      create  MyCoolLib/LICENSE
      create  MyCoolLib/README.md
      create  MyCoolLib/.travis.yml
      create  MyCoolLib/Projectfile
      create  MyCoolLib/src/MyCoolLib.cr
      create  MyCoolLib/src/MyCoolLib/version.cr
      create  MyCoolLib/spec/spec_helper.cr
      create  MyCoolLib/spec/MyCoolLib_spec.cr
Initialized empty Git repository in ~/MyCoolLib/.git/
```

## Other commands and options

To see the full set of commands, invoke `crystal` without arguments.

```
$ crystal
Usage: crystal [command] [switches] [program file] [--] [arguments]

Command:
    init                     generate new crystal project
    build                    compile program file
    browser                  open an http server to browse program file
    deps                     install project dependencies
    docs                     generate documentation
    eval                     eval code
    hierarchy                show type hierarchy
    run (default)            compile and run program file
    spec                     compile and run specs (in spec directory)
    types                    show type of main variables
    --help                   show this help
    --version                show version
```

To see the available options for a particuar command, use `--help` after a command:

```
$ crystal build --help
Usage: crystal build [options] [programfile] [--] [arguments]

Options:
    --cross-compile flags            cross-compile
    -d, --debug                      Add symbolic debug info
    -D FLAG, --define FLAG           Define a compile-time flag
    --emit [asm|llvm-bc|llvm-ir|obj] Comma separated list of types of output for the compiler to emit
    -h, --help                       Show this message
    --ll                             Dump ll to .crystal directory
    --link-flags FLAGS               Additional flags to pass to the linker
    --mcpu CPU                       Target specific cpu type
    --no-color                       Disable colored output
    --no-build                       Disable build output
    -o                               Output filename
    --prelude                        Use given file as prelude
    --release                        Compile in release mode
    -s, --stats                      Enable statistics output
    --single-module                  Generate a single LLVM module
    --threads                        Maximum number of threads to use
    --target TRIPLE                  Target triple
    --verbose                        Display executed commands
```
