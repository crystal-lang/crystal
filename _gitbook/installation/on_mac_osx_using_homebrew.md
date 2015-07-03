# On Mac OSX using Homebrew

To easily install Crystall on Mac you can use our [Homebrew](http://brew.sh/) [tap](https://github.com/Homebrew/homebrew/wiki/brew-tap)

```
brew tap manastech/crystal
brew update
brew install crystal-lang
```

If you're planning to contribute to the project you might find useful to install LLVM as well. So replace the last line with:

```
brew install crystal-lang --with-llvm
```
