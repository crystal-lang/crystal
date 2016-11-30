# Contributing to Crystal

You've decided to contribute to Crystal. Excellent!

## What's needed right now

You can find a list of tasks that we consider suitable for a first time contribution at
the [newcomer label](https://github.com/crystal-lang/crystal/labels/newcomer).

Furthermore these are the most important general things in need right now:

* Documenting the language
* Documenting the standard library
* Adding missing bits of the standard library, and/or improving its performance

## Contributing to the documentation

The main website is at [crystal-lang/crystal-website](https://github.com/crystal-lang/crystal-website),
please have a look over there if you want to contribute to it.

We use [GitBook](https://www.gitbook.com/) for the [language documentation](https://crystal-lang.org/docs/).
See the repository at [crystal-lang/crystal-book](https://github.com/crystal-lang/crystal-book) for how to contribute to it.

The [standard library documentation](https://crystal-lang.org/api/) is on the code itself, in this repository.
There is a version updated with every push to the master branch [here](https://crystal-lang.org/api/master/).
It uses a subset of [Markdown](http://daringfireball.net/projects/markdown/). You can [use Ruby as a source
of inspiration](https://twitter.com/yukihiro_matz/status/549317901002342400) whenever applicable. To generate
the docs execute `make doc`. Please follow the guidelines described in our
[language documentation](https://crystal-lang.org/docs/conventions/documenting_code.html), like the use of the third person.

## Contributing to the standard library

1. Fork it ( https://github.com/crystal-lang/crystal/fork )
2. Clone it

Be sure to execute `make libcrystal` inside the cloned repository.

Once in the cloned directory, and once you [installed Crystal](http://crystal-lang.org/docs/installation/index.html),
you can execute `bin/crystal` instead of `crystal`. This is a wrapper that will use the cloned repository
as the standard library. Otherwise the barebones `crystal` executable uses the standard library that comes in
your installation.

Next, make changes to the standard library, making sure you also provide corresponding specs. To run
the specs for the standard library, run `make std_spec`. To run a particular spec: `bin/crystal spec/std/array_spec.cr`.
You can use `make help` for a list of available make targets.

Note: at this point you might get long compile error that include "library not found for: ...". This means
you are [missing some libraries](https://github.com/crystal-lang/crystal/wiki/All-required-libraries).

Make sure that your changes follow the recommended [Coding Style](https://crystal-lang.org/docs/conventions/coding_style.html).
You can run `crystal tool format` to automate this.

Then push your changes and create a pull request.

## Contributing to the compiler itself

If you want to add/change something in the compiler,
the first thing you will need to do is to [install the compiler](https://crystal-lang.org/docs/installation/index.html).

Once you have a compiler up and running, check that executing `crystal` on the command line prints its usage.
Now you can setup your environment to compile Crystal itself, which is itself written in Crystal. Check out
the `install` and `before_install` sections found in [.travis.yml](https://github.com/crystal-lang/crystal/blob/master/.travis.yml).
These set-up LLVM 3.6 and its required libraries.

Next, executing `make clean crystal spec` should compile a compiler and using that compiler compile and execute
the specs. All specs should pass. You can use `make help` for a list of available make targets.

## Maintain clean pull requests

The commit history should consist of commits that transform the codebase from one state into another one, motivated by something that
should change, be it a bugfix, a new feature or some ground work to support a new feature, like changing an existing API or introducing
a new isolated class that is later used in the same pull request. It should not show development history ("Start work on X",
"More work on X", "Finish X") nor review history ("Fix comment A", "Fix comment B"). Review fixes should be squashed into the commits
that introduced them. If your change fits well into a single commit, simply keep editing it with `git commit --amend`. Partial staging and
committing with `git add -p` and `git commit -p` respectively are also very useful. Another good tool is `git stash` to put changes aside while
switching to another commit. But Git's most useful tool towards this goal is the interactive rebase.

### Doing an interactive rebase

First let's make sure we have a clean reference to rebase upon:

```sh
git remote add upstream https://github.com/crystal-lang/crystal.git
```

That only needs to be done once per clone. Next, let's fetch the latest state and start the rebase

```sh
git fetch upstream
git checkout my_feature_branch
git rebase -i upstream/master # Or upstream/gh-pages for contributing to the out of code documentation
```

Now you should be presented with a list of commits in your editor, with the first commit you made on your branch at the top. Always keep the first
entry at `pick`; however you can reorder the entries. `squash` and `fix` will combine a commit into the one above it, `edit` will pause the
rebase so you can edit the commit with `git commit --amend`. In case of conflicts `git mergetool` can be useful to resolve them. To resume a
paused rebase, either because of a conflict or `edit`, use `git rebase --continue`. Don't worry, you can at any point use `git rebase --abort`
to return to where you were before the rebase and start from scratch.

Other useful flags to `git commit` are `--fixup` and `--squash`, combined with `git rebase -i --autosquash upstream/master`. Those will create commits that
are then automatically reordered and marked with `fix` or `squash` respectively.

Once you have a clean history, you can update an existing pull request simply by force pushing to the branch you opened it from. Force pushing is necessary
since a rebase rewrites history, effectively creating new commits with the same changes. However, never do that in the main integration branches (`master`) of
your own projects; a not so clean history is to prefer once a commit landed there. Assuming `origin` is your fork on Github, simply:

```sh
git push -f origin my_feature_branch
```

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

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct][ccoc].
By participating in this project you agree to abide by its terms.

[ccoc]: https://github.com/crystal-lang/crystal/blob/master/CODE_OF_CONDUCT.md
