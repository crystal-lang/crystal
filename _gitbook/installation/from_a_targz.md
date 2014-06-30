# From a tar.gz

First, you need to fulfil some dependencies:

* LLVM 3.3 and Clang
* The latest version of the Boehm-Demers-Weiser conservative garbage collector
* libunwind
* libpcre

Then, depending on your platform, you need to download one of these:

* Mac OSX: [crystal-darwin-latest.tar.gz](http://crystal-lang.s3.amazonaws.com/crystal-darwin-latest.tar.gz)
* Linux 32 bits: [crystal-linux32-latest.tar.gz](http://crystal-lang.s3.amazonaws.com/crystal-linux32-latest.tar.gz)
* Linux 64 bits: [crystal-linux64-latest.tar.gz](http://crystal-lang.s3.amazonaws.com/crystal-linux64-latest.tar.gz)

Then uncompress it and inside it you will have a `bin/crystal` executable.

To make it simpler to use, you can create a symbolic link to the executable:

`ln -s [full path to bin/crystal] /usr/local/bin/crystal`

Then you can invoke crystal by just typing `crystal`.
