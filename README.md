Crystal
=======

Crystal is a programming language with the following goals:

* Have the same syntax as Ruby, or at least as similar as possible.
* Never have to specify the type of a variable or method argument.
* Be able to call C code by writing bindings to it in Crystal.
* Have compile-time evaluation and generation of code, to avoid boilerplate code.
* Compile to efficient native code.

Interested? Read the [introduction](https://github.com/manastech/crystal/wiki/Introduction) or the [docs for developers](https://github.com/manastech/crystal/wiki/Developers).

Why?
----

We love Ruby's efficiency for writing code.

We love C's efficiency for running code.

We want the best of both worlds.

We want the compiler to understand what we mean without having to specify types everywhere.

We want full OOP.

Oh, and we don't want to write C code to make the code run faster.

Installing
----------

You will need:

* Ruby 1.9
* LLVM 3.1 installed as a shared library.

Then:

1. Clone the repository
1. Install `bundler` if you don't have it already: `gem install bundler`
1. Execute `bundle`

Finally run crystal:

> `bin/crystal --help`
