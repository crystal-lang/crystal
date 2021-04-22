# Crystal

[![Linux CI](https://github.com/crystal-lang/crystal/workflows/Linux%20CI/badge.svg)](https://github.com/crystal-lang/crystal/actions?query=workflow%3A%22Linux+CI%22+event%3Apush+branch%3Amaster)
[![macOS CI](https://github.com/crystal-lang/crystal/workflows/macOS%20CI/badge.svg)](https://github.com/crystal-lang/crystal/actions?query=workflow%3A%22macOS+CI%22+event%3Apush+branch%3Amaster)
[![AArch64 CI](https://github.com/crystal-lang/crystal/workflows/AArch64%20CI/badge.svg)](https://github.com/crystal-lang/crystal/actions?query=workflow%3A%22AArch64+CI%22+event%3Apush+branch%3Amaster)
[![Windows CI](https://github.com/crystal-lang/crystal/workflows/Windows%20CI/badge.svg)](https://github.com/crystal-lang/crystal/actions?query=workflow%3A%22Windows+CI%22+event%3Apush+branch%3Amaster)
[![CircleCI Build Status](https://circleci.com/gh/crystal-lang/crystal/tree/master.svg?style=shield)](https://circleci.com/gh/crystal-lang/crystal)
[![Join the chat at https://gitter.im/crystal-lang/crystal](https://badges.gitter.im/crystal-lang/crystal.svg)](https://gitter.im/crystal-lang/crystal)
[![Code Triagers Badge](https://www.codetriage.com/crystal-lang/crystal/badges/users.svg)](https://www.codetriage.com/crystal-lang/crystal)

---

[![born-and-raised](https://cloud.githubusercontent.com/assets/209371/13291809/022e2360-daf8-11e5-8be7-d02c1c8b38fb.png)](https://manas.tech/)

Crystal is a programming language with the following goals:

* Have a syntax similar to Ruby (but compatibility with it is not a goal)
* Statically type-checked but without having to specify the type of variables or method arguments.
* Be able to call C code by writing bindings to it in Crystal.
* Have compile-time evaluation and generation of code, to avoid boilerplate code.
* Compile to efficient native code.

Why?
----

We love Ruby's efficiency for writing code.

We love C's efficiency for running code.

We want the best of both worlds.

We want the compiler to understand what we mean without having to specify types everywhere.

We want full OOP.

Oh, and we don't want to write C code to make the code run faster.

Project Status
--------------

Within a major version language features won't be removed or changed in any way that could prevent an existing code to keep compiling and working. And the built in standard library might be enriched but always with backward compatibility in mind.

The development is possible thanks to the community's effort and the continued support of [84codes](https://www.84codes.com/), [Nikola Motor Company](https://nikolamotor.com/) and every other [sponsor](https://crystal-lang.org/sponsors).

Installing
----------

[Follow these instructions](https://crystal-lang.org/install)

Try it online
-------------

[play.crystal-lang.org](https://play.crystal-lang.org/)

Documentation
-------------

* [Language Reference](http://crystal-lang.org/reference)
* [Standard library API](https://crystal-lang.org/api)
* [Roadmap](https://github.com/crystal-lang/crystal/wiki/Roadmap)

Community
---------

Questions or suggestions? Ask on the [Crystal Forum](https://forum.crystal-lang.org), on our [Gitter channel](https://gitter.im/crystal-lang/crystal) or IRC channel [#crystal-lang](http://webchat.freenode.net/?channels=#crystal-lang) at chat.freenode.net, or on Stack Overflow under the [crystal-lang](http://stackoverflow.com/questions/tagged/crystal-lang) tag. There is also an archived [Google Group](https://groups.google.com/forum/?fromgroups#!forum/crystal-lang).

Contributing
------------

The Crystal repository is hosted at [crystal-lang/crystal](https://github.com/crystal-lang/crystal) on GitHub.

Read the general [Contributing guide](https://github.com/crystal-lang/crystal/blob/master/CONTRIBUTING.md), and then:

1. Fork it (<https://github.com/crystal-lang/crystal/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
