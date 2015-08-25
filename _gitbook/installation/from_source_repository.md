# From sources

If you want to contribute then you might want to install Crystal from sources. But Crystal is written in Crystal itself! So you first need to use one of the previous described methods to have a running compiler.

You will also need LLVM 3.5 present in the path. If you are using Mac and the Homebrew formula, this will be automatically configured for you if you install Crystal adding `--with-llvm` flag.

Then clone the repository:

```
git clone https://github.com/manastech/crystal.git
```

and you're ready to start hacking.

To build your own version of the compiler, run `make`. The new compiler will be placed at `.build/crystal`.

Make sure to install [all the required libraries](https://github.com/manastech/crystal/wiki/All-required-libraries). You might also want to read the [contributing guide](https://github.com/manastech/crystal/blob/master/Contributing.md).

Inside the repository you will also find a wrapper script at `bin/crystal`. This script will execute the global installed compiler or the one that you just compiled (if present).
