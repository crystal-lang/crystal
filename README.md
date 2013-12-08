Crystal [![Build Status](https://travis-ci.org/manastech/crystal.png)](https://travis-ci.org/manastech/crystal) [![Build Status](https://drone.io/github.com/manastech/crystal/status.png)](https://drone.io/github.com/manastech/crystal/latest)
=======

Crystal is a programming language with the following goals:

* Have the same syntax as Ruby, or at least as similar as possible.
* Never have to specify the type of a variable or method argument.
* Be able to call C code by writing bindings to it in Crystal.
* Have compile-time evaluation and generation of code, to avoid boilerplate code.
* Compile to efficient native code.

Interested? Read the [introduction](https://github.com/manastech/crystal/wiki/Introduction) or the [docs for developers](https://github.com/manastech/crystal/wiki/Developers).

Questions or suggestions? Ask in our [Google Group](https://groups.google.com/forum/?fromgroups#!forum/crystal-lang) or join our IRC channel #crystal-lang at irc.freenode.net

Why?
----

We love Ruby's efficiency for writing code.

We love C's efficiency for running code.

We want the best of both worlds.

We want the compiler to understand what we mean without having to specify types everywhere.

We want full OOP.

Oh, and we don't want to write C code to make the code run faster.

Status
------

* The project is in pre-alpha stage: we are still designing the language.
* The compiler is written in Crystal.
* Includes the Boehm-Demers-Weiser conservative garbage collector, but this will change in the future.

Installing
----------

Currently it only works on Mac OSX 64 bit (but this will change soon, we promise!)

1. Clone the repository
1. Execute `bin/crystal --setup`
1. You will need libgc. In mac: `brew install bdw-gc`. In Ubuntu: `sudo apt-get install libgc`.

That's all. Try to run:

> `bin/crystal --help`

Or compile some example:

> `bin/crystal samples/mandelbrot.cr && ./mandelbrot`

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/25b65355cae65602787d6952d0bdb8cf "githalytics.com")](http://githalytics.com/manastech/crystal)
