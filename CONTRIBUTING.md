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

The language reference is available at https://crystal-lang.org/reference/.
See the repository at [crystal-lang/crystal-book](https://github.com/crystal-lang/crystal-book) for contributing to it.

The [standard library documentation](https://crystal-lang.org/api/) is on the code itself, in this repository.
There is a version updated with every push to the master branch [here](https://crystal-lang.org/api/master/).
It uses a subset of [Markdown](http://daringfireball.net/projects/markdown/). You can [use Ruby as a source
of inspiration](https://twitter.com/yukihiro_matz/status/549317901002342400) whenever applicable. To generate
the docs execute `make docs`. Please follow the guidelines described in our
[language documentation](https://crystal-lang.org/reference/conventions/documenting_code.html), like the use of the third person.

Additionally, all official documentation can be found on [the Crystal website](https://crystal-lang.org/docs/).

### The standard library

1. Fork it ( https://github.com/crystal-lang/crystal/fork )
2. Clone it

Once in the cloned directory, and once you [installed Crystal](https://crystal-lang.org/install/),
you can execute `bin/crystal` instead of `crystal`. This is a wrapper that will use the cloned repository
as the standard library. Otherwise the barebones `crystal` executable uses the standard library that comes in
your installation.

Next, make changes to the standard library, making sure you also provide corresponding specs. To run
the specs for the standard library, run `make std_spec`. To run a particular spec: `bin/crystal spec spec/std/array_spec.cr`.
You can use `make help` for a list of available make targets.

Note: at this point you might get long compile error that include "library not found for: ...". This means
you are [missing some libraries](https://github.com/crystal-lang/crystal/wiki/All-required-libraries).

Make sure that your changes follow the recommended [Coding Style](https://crystal-lang.org/reference/conventions/coding_style.html).
You can run `crystal tool format` to automate this.

Then push your changes and create a pull request.

### The compiler itself

If you want to add/change something in the compiler,
the first thing you will need to do is to [install the compiler](https://crystal-lang.org/install/).

Once you have a compiler up and running, check that executing `crystal` on the command line prints its usage.
Now you can setup your environment to compile Crystal itself, which is itself written in Crystal.

The compiler needs [LLVM](https://llvm.org) and some other libraries. See [list of all required libraries](https://github.com/crystal-lang/crystal/wiki/All-required-libraries).

Executing `make crystal` builds the compiler into `.build/compiler` and you can run it using the wrapper script at `bin/crystal`.
The script sets up the proper environment variables that the compiler can find the standard library source files in `src/`.

`make compiler_spec` runs the compiler specs. `make std_spec` runs the standard library specs.
You can use `make help` for a list of available make targets.

## This guide

If this guide is not clear and it needs improvements, please send pull requests against it. Thanks! :-)

## Making good pull requests

The commit history should consist of commits that transform the codebase from one state into another one, motivated by something that
should change, be it a bugfix, a new feature or some ground work to support a new feature, like changing an existing API or introducing
a new isolated class that is later used in the same pull request.

Review history should be preserved in a pull request. If you need to push a change to an open pull request (for example
because specs broke and required a fix, or for applying a review suggestion) these changes should be added as individual
fixup commits. Please do not amend previous commits and force push to the PR branch. This makes reviews much harder
because reference to previous state is hidden.

If changes introduced to `master` branch result in conflicts, it should be merged with a merge commit (`git fetch upstream/master; git merge upstream/master`).

### Minimum requirements

1. Describe reasons and result of the change in the pull request comment.
2. Do not force push to a pull request. The development history should be easily traceable.
3. Any change to a public API requires appropriate documentation: params (and particularly interesting combinations of them if the method is complex), results, interesting, self-contained examples.
4. Any change to behaviour needs to be reflected and validated with specs.
5. Any change affecting the compiler or performance-critical features in the standard library
   should be checked with benchmarks how it affects performance.

### Approval Process

1. To be accepted, a pull request requires recent approvals from at least two core team members; if the author is a core team
   member, this counts as one approval. Approvals only count when based on the current code version (except for minor changes like fixing a typo).
2. When the required approvals are given and CI is satisfied, a core team member can add the pull request to the
   current development milestone. This signals that it is scheduled to be merged soon and gives another chance for final reviews.
3. The wait time in this state depends on the gravity of the change and the activity of the previous discussion,
   but it should at least be a full business day after the milestone was added.
4. Before merging, make sure the pull request is properly labeled and its title appropriately describes the change.
4. Finally, the pull request can be merged. Use squash merge to not pollute the version history of the main branch with
   details of the pull request process. For non-trivial changes, the merge commit should contain a short description.

This process is a guideline and not a strict rule so there might be occasional exceptions within reason.
Urgent infrastructure fixes for example can be expected to skip the line.

### For maintainers with push access

1. Do not directly commit to the `master` branch. Always create a feature branch and pull request.
2. Feature branches should typically be created in your fork. The main repo should only contain essential branches.

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
