# From sources

If you want to contribute (or simply run the very latest Crystal) then you will want to build Crystal from sources.  But since Crystal is written in Crystal - you can't compile Crystal unless you've already compiled Crystal!  Don't worry, you simply need to use a pre-built Crystal compiler for your platform to bootstrap the process.

## Pre-requisites

You'll first need to use one of the previous installation methods to install a pre-built Crystal compiler. (since you need Crystal to compile Crystal)

You will also need LLVM 3.5 present in the path. If you are using Mac and the Homebrew formula, this will have been automatically configured for you if you installed Crystal using the `--with-llvm` flag.

## Getting the code

Just clone the repository and you're ready to start hacking.

```
git clone https://github.com/manastech/crystal.git
cd crystal
# hack away
```

## Building

To build your own version of the compiler:

```
make
```

The new compiler will be placed at `.build/crystal`.

Inside the repository you will also find a wrapper script at `bin/crystal`. This script will execute the global installed compiler or the one that you just compiled (if present).

## Running the specs

To ensure your compiler was built and is working properly you'll want to run the included specs.

```
make spec
```

The output should include a bunch of dots and asterisks and then a summary like the following:

```
<snip>
........................................................*..................*....
......................................................................................
..................................................
<snip>
Finished in 1:29 minutes
5734 examples, 0 failures, 0 errors, 15 pending
```

If there are failures or errors that likely indicates a problem with your compiler - or possibly you haven't updated any specs that might have been affected by changes you've made.

---

### Quick Steps

Once you have LLVM 3.5 and a working Crystal compiler:

```
git clone https://github.com/manastech/crystal.git
cd crystal
make crystal
make spec
```
