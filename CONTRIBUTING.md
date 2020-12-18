# Contributing to Crystal

So you've decided to contribute to Crystal. Excellent!

## Using the issue tracker

The [issue tracker](https://github.com/crystal-lang/crystal/issues) is the heart of Crystal's work. Use it for bugs, questions, proposals and feature requests.

Please always **open a new issue before sending a pull request** if you want to add a new feature to Crystal, unless it is a minor fix, and wait until someone from the core team approves it before you actually start working on it. Otherwise, you risk having the pull request rejected, and the effort implementing it goes to waste. And if you start working on an implementation for an issue, please **let everyone know in the comments** so someone else does not start working on the same thing.

Regardless of the kind of issue, please make sure to look for similar existing issues before posting; otherwise, your issue may be flagged as `duplicated` and closed in favour of the original one. Also, once you open a new issue, please make sure to honour the items listed in the issue template.

If you open a question, remember to close the issue once you are satisfied with the answer and you think
there's no more room for discussion. We'll anyway close the issue after some days.

If something is missing from the language it might be that it's not yet implemented or that it was purposely left out. If in doubt, just ask.

### What's needed right now

You can find a list of tasks that we consider suitable for a first time contribution at
the [newcomer label](https://github.com/crystal-lang/crystal/issues?q=is%3Aissue+is%3Aopen+label%3Acommunity%3Anewcomer).

As you feel more confident, you can keep an eye out for open issues with the following labels:
* [`community:to-research`](https://github.com/crystal-lang/crystal/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen%20label%3Acommunity%3Ato-research): Help needed on **researching and investigating** the issue at hand; could be from going through an RFC to figure out how something _should_ be working, to go through details on a C-library we'd like to bind.
* [`community:to-design`](https://github.com/crystal-lang/crystal/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen%20label%3Acommunity%3Ato-design): As an issue has been accepted, we are looking for **ideas on how it could be implemented**, this is, a high-level design for the feature at hand.
* [`community:to-implement`](https://github.com/crystal-lang/crystal/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen%20label%3Acommunity%3Ato-implement): After a design has been agreed upon, the remaining task is to actually **code** it and send a PR!
* [`community:to-document`](https://github.com/crystal-lang/crystal/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen%20label%3Acommunity%3Ato-document): Similar to the one above, but this one is for those awesome devs that are happy to **contribute with documentation** instead of just code.

Furthermore, these are the most important general topics in need right now, so if you are interested open an issue to start working on it:

* Documenting the language
* Documenting the standard library
* Adding missing bits of the standard library, and/or improving its performance

### Labels

Issue tracker labels are sorted by category: community, kind, pr, status and topic.

#### Community

These are the issues where help from the community is most welcome. See above for a description on `newcomer`, `to-research`, `to-design`, `to-implement` and `to-document`.

Label `in-progress` is used to signal that someone from the community is already working on the issue (since Github does not allow for a non-team member to be _assigned_ to an issue).

The label `shard-idea` refers to a feature proposal that, albeit good, is better suited as a separate shard rather than as part of the core library; so if you are looking for a shard of your own to start working on, these issues are good starting points.

#### Kind

The most basic category is the kind of the issue: `bug`, `feature` and `question` speak for themselves, while `refactor` is left for changes that do not actually introduce a new a feature, and are not fixing something that is broken, but rather clean up the code (or documentation!).

#### PR

Pull-request only labels, used to signal that a pull request `needs-review` by a core team member, or that is still `wip` (work in progress).

#### Topic

Topic encompasses the broad aspect of the language that the issue refers to: could be performance, the compiler, the type system, the code formatter, concurrency, and quite a large etc.

#### Status

Status labels attempt to capture the lifecycle of an issue:

* A detailed proposal on a feature is marked as `draft`, while a more general argument is usually labelled as `discussion` until a consensus is achieved.

* An issue is `accepted` when it describes a feature or bugfix that a core team member has agreed to have added to the language, so as soon as a design is discussed (if needed), it's safe to start working on a pull request.

* Bug reports are marked as `needs-more-info`, where the author is requested to provide the info required; note that the issue may be closed after some time if it is not supplied.

* Issues that are batched in an epic to be worked on as a group are typically marked as `deferred`, while low-prio issues or tasks far away in the roadmap are marked as `someday`.

* Closed issues are marked as `implemented`, `invalid`, `duplicate` or `wontfix`, depending on their resolution.

## Contributing to...

### The documentation

We use [GitBook](https://www.gitbook.com/) for the [language documentation](https://crystal-lang.org/docs/).
See the repository at [crystal-lang/crystal-book](https://github.com/crystal-lang/crystal-book) for how to contribute to it.

The [standard library documentation](https://crystal-lang.org/api/) is on the code itself, in this repository.
There is a version updated with every push to the master branch [here](https://crystal-lang.org/api/master/).
It uses a subset of [Markdown](http://daringfireball.net/projects/markdown/). You can [use Ruby as a source
of inspiration](https://twitter.com/yukihiro_matz/status/549317901002342400) whenever applicable. To generate
the docs execute `make docs`. Please follow the guidelines described in our
[language documentation](https://crystal-lang.org/docs/conventions/documenting_code.html), like the use of the third person.

### The standard library

1. Fork it ( https://github.com/crystal-lang/crystal/fork )
2. Clone it

Be sure to execute `make libcrystal` inside the cloned repository.

Once in the cloned directory, and once you [installed Crystal](https://crystal-lang.org/install/),
you can execute `bin/crystal` instead of `crystal`. This is a wrapper that will use the cloned repository
as the standard library. Otherwise the barebones `crystal` executable uses the standard library that comes in
your installation.

Next, make changes to the standard library, making sure you also provide corresponding specs. To run
the specs for the standard library, run `make std_spec`. To run a particular spec: `bin/crystal spec spec/std/array_spec.cr`.
You can use `make help` for a list of available make targets.

Note: at this point you might get long compile error that include "library not found for: ...". This means
you are [missing some libraries](https://github.com/crystal-lang/crystal/wiki/All-required-libraries).

Make sure that your changes follow the recommended [Coding Style](https://crystal-lang.org/docs/conventions/coding_style.html).
You can run `crystal tool format` to automate this.

Then push your changes and create a pull request.

### The compiler itself

If you want to add/change something in the compiler,
the first thing you will need to do is to [install the compiler](https://crystal-lang.org/install/).

Once you have a compiler up and running, check that executing `crystal` on the command line prints its usage.
Now you can setup your environment to compile Crystal itself, which is itself written in Crystal. Check out
the `install` and `before_install` sections found in [.travis.yml](https://github.com/crystal-lang/crystal/blob/master/.travis.yml).
These set-up LLVM 3.6 and its required libraries.

Next, executing `make clean crystal spec` should compile a compiler and using that compiler compile and execute
the specs. All specs should pass. You can use `make help` for a list of available make targets.

## This guide

If this guide is not clear and it needs improvements, please send pull requests against it. Thanks! :-)


## Making good pull requests

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
git rebase -i upstream/master
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

## Git pre-commit hook

Code submitted to this repository should be formatted according to `crystal tool format`.
A pre-commit hook can be installed into the local git repo to ensure the formatter validates every commit: https://github.com/crystal-lang/crystal/blob/master/scripts/git/pre-commit

Install the pre-commit hook:

```sh
ln -s scripts/git/pre-commit .git/hooks
```

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct][ccoc].
By participating in this project you agree to abide by its terms.

[ccoc]: https://github.com/crystal-lang/crystal/blob/master/CODE_OF_CONDUCT.md
