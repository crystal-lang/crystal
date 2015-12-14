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

Reinstall Xcode Command Line Tools, then set the path for the active developer directory.

```
xcode-select --install
xcode-select --switch /Library/Developer/CommandLineTools
``
