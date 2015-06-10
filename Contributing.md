# Contributing to Crystal

You've decided to contribute to Crystal. Excellent!

## What's needed right now

These are the most important things in need right now:

* Documenting the language
* Documenting the standard library
* Adding missing bits of the standard library, and/or improving its performance

## Contributing to the documentation

The main site and official language documentation is on the `gh-pages` branch. Just check it out
and do `rake build && jekyll serve` to browse it. We use [GitBook](https://www.gitbook.com/) for the documentation,
check the `_gitbook` directory.

The standard library documentation is on the code itself.
It uses a subset of [Markdown](http://daringfireball.net/projects/markdown/). You can [use Ruby as a source
of inspiration](https://twitter.com/yukihiro_matz/status/549317901002342400) whenever applicalble. To generate
the docs execute `make doc`.

## Contributing to the standard library

1. Fork it ( https://github.com/manastech/crystal/fork )
2. Clone it

Once in the cloned directory, and once you [installed Crystal](http://crystal-lang.org/docs/installation/index.html),
you can execute `bin/crystal` instead of `crystal`. This is a wrapper that will use the cloned repository
as the standard library. Otherwise the barebones `crystal` executable uses the standard library that comes in
your installation.

Next, make changes to the standard library, making sure you also provide corresponding specs. To run all specs
you can do `make spec` or `bin/crystal spec/all_spec.cr`. To run a particular spec: `bin/crystal spec/std/array_spec.cr`.

Then push your changes and create a pull request.

## Contributing to the compiler itself

If you want to add/change something in the compiler,
the first thing you will need to do is to [install the compiler](http://crystal-lang.org/docs/installation/index.html).

Once you have a compiler up and running, and that executing `crystal` on the command line prints its usage,
it's time to setup your environment to compile Crystal itself, which is written in Crystal. Check out
the `install` and `before_install` sections found in [.travis.yml](https://github.com/manastech/crystal/blob/master/.travis.yml).
These set-up LLVM and its required libraries.

**Note**: if you are on a Mac make sure to install the LLVM that is used in that travis script, the LLVM that you download
or get from homebrew has a bug (uninstall the LLVM from homebrew too).

Next, executing `make clean crystal spec` should compile a compiler and using that compiler compile and execute
the specs. All specs should pass.

## Using the issue tracker

Use the issue tracker for bugs, questions, proposals and feature requests.
The issue tracker is very convenient for all of this because of its ability to link to a particular commit
or another issue, include code snippets, etc.
If you open a question, remember to close the issue once you are satisfied with the answer and you think
there's no more room for discussion. We'll anyway close the issue after some days.

If something is missing from the language it might be that it's not yet implemented
(the language is still very young) or that it was purposely left out. If in doubt, just ask.

## Contributing to this guide

If this guide is not clear and it needs improvements, please send pull requests against it. Thanks! :-)
