# From source repository

First, you need to fulfil some dependencies:

* Clang or GCC
* The latest version of the Boehm-Demers-Weiser conservative garbage collector
* libunwind
* libpcre

Then:

1. Clone the repository: git clone git@github.com:manastech/crystal.git
1. Execute `bin/crystal --setup`

Then you will have available the `bin/crystal` executable.

To make it simpler to use, you can create a symbolic link to the executable:

`ln -s [full path to bin/crystal] /usr/local/bin/crystal`

Then you can invoke crystal by just typing `crystal`.
