# On Mac OSX using Homebrew

To easily install Crystal on Mac you can use [Homebrew](http://brew.sh/).

```
brew update
brew install crystal-lang
```

If you're planning to contribute to the project you might find useful to install LLVM as well. So replace the last line with:

```
brew install crystal-lang --with-llvm
```

## Troubleshooting on OSX 10.11 (El Capitan)

If you get an error like:

```
ld: library not found for -levent
```

you need to reinstall the command line tools and then select the default active toolchain:

```
$ xcode-select --install
$ xcode-select --switch /Library/Developer/CommandLineTools
```
