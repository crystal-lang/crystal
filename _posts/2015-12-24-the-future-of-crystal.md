---
layout: post
title: The future of Crystal
summary: A short story
thumbnail: 🎄
author: asterite
---

(This post is part of [Crystal Advent Calendar 2015](http://www.adventar.org/calendars/800))

This Christmas eve something curious happened: we were happily coding in Crystal
when, one moment when we took our eyes away from the screen, a translucid figure appeared nearby.
The entity approached and said: "I'm the Ghost of Christmas Past. Come with me."

We saw ourselves coding a new language that would resemble Ruby but be compiled and type safe.
At that moment the language was really like Ruby: to create an empty Array you would write `[]`, or
`Set.new` to create an empty set. And we were happy, until we realized compile times were huge,
exponential, unbearable, and got sad.

We spent an awful time trying to make it work with no avail. Finally, we decided to make a change:
speficy the types of empty generic types, for example `[] of Int32` or `Set(Int32).new`.
Compile times were back to normal. And we were kind of happy again, but at the same time felt
that we were leaving behind some of Ruby's feeling. The language diverged.

We looked back at the Ghost of Christmas Past to ask him what did all of that mean, but we
found a similar but different figure in its place. She said:
"I'm the Ghost of Christmas Present. Join me."

Around us, a small but vibrant community was programming in Crystal. They were happy.
There was no mention of the annoyance of having to specify types for generic types. Everyone
was feeling that Ruby's spirit was somehow still present: in the familiar API and classes,
in the syntax, in the powerful blocks. Additionally, the increased performance, both in terms of
CPU and concurrency, coupled with better type safety, really paid off, so having to specify
a type now and then didn't feel like bothersome.

Again, we looked at the Ghost to ask for a meaning: it seemed that we took a good decision in the
past, right? But, just as before, there was something else in its place, a mechanical crystalline
figure. It spoke: "I'm the Ghost of Christmas Yet to Come. Follow me."

The small community was still programming in Crystal, though most didn't seem to be as happy as before.
We tried to ask them why, but nobody noticed our presence. We tried to use a computer and search
for Crystal on the internet, but our hands couldn't touch anything. We turned to the Ghost with
an inquisitive face, and noticed it had a keyboard and a small screen in its chest. We searched
"Crystal sucks", which would hopefully show posts of complaints about the language. And indeed
there were quite a few of them. Most were about huge compile times and memory usage.
"Huge compile times?", we thought. "We solved that years ago!", we shouted to the Ghost.
The only reply we got from it was "compiling...", the vision faded and we were back at the office, alone.

## Back to the present

"Let's do some math", we said. The biggest program we have in Crystal right now is the
compiler, which has about 40K lines of code. It takes about 10 seconds to compile,
and it takes 940MB of memory to do so. One of our Rails apps, counting the total number of lines
in its gems and the code in the "app" directory, has about 320K line of code, 8 times bigger than the compiler.
If we rewrite it in Crystal, or at least do an application with a similar functionality, it would
take 80 seconds to compile it, each time, and 8GB of memory to do so. That's a lot of time to wait
after each change, and an awful lot of memory too.

Can we improve this situation, with the current language? Can we introduce incremental compilation?
We spent some time thinking about how to cache a previous compilation's semantic result (inferred types)
and use that for the next compilation. An observation is that a method's type depends exclusively on the type
of the arguments, the type of the methods it invokes, and the types of instance, class, and global variables.

So, one idea is to cache the inferred instance variables types of all the types in
a program, together with the types of method instantiations and its dependencies (on which types that
method depends, and specifically which other methods it calls). If instance variables types remain
the same, a method's code didn't change, and the dependencies (invoked methods) didn't change,
we can safely reuse the result (types and generated code) from the previous compilation.

Note that the above "if" starts with "if instance variables types remain the same". But how can we
know that? The problem is that the compiler determines their type by traversing the program,
instantiating methods, and checking what gets assigned to them. So we can't really reuse the cache
because we can't know the final types until we type the whole program! It's a chicken and egg problem.

The solution seems to be having to specify types of instance, class and global variables. With this,
once we type a method its type can never change (because everything that's non-local to a method, like
instance variables, can't change anymore). We would be able to cache that information and reuse it for
next compilations. Not only that, but type inference becomes much simpler and faster, even without a
cache.

Is this the right thing to do? We will once again diverge a bit more from Ruby. What future do we want?
Do we want to stick with the current approach at the cost of having to wait a lot of time between each
compilation? Or is it better to specify some more types but have a more agile development cycle?

What we really want is a language that's fun to use, and efficient. Having
to wait a lot of time for compilation to finish isn't fun at all, even less fun that having to
annotate a few types now and then. And these types are just for generic, instance, class and global
variables: no types annotations are required in local variables and method arguments. Considering
how rarely these types change, compared to how many times you are going to be writing new methods
and compiling your program, it feels it's something worth of a change.

We already started working on this new compiler, because we want to do this as soon as possible as a lot of
code out there will break. While the current compiler works directly on the
[AST](https://en.wikipedia.org/wiki/Abstract_syntax_tree), in the new compiler we work with
a [flow graph](https://en.wikipedia.org/wiki/Control_flow_graph), which will allow us to
have a simpler compiler (one which anyone could understand and jump right into it and contribute)
and easier to understand and optimize code. It will also make it possible to introduce new features
like Ruby's `retry` with minimal effort, because the flow graph allows for cycles and "goto"-like
jumps.

If you'd like to know more about this change, there's a [tracking issue](https://github.com/manastech/crystal/issues/1824)
about it.

## Questions and Answers

* **When will you finish the new compiler?** We don't know yet. We are working on it slowly but steadily,
  writing it with readability, extensibility and efficiency in mind, and focusing on the hardest parts first.
  Now that we know most of the features the language supports, it's easier. Remember that the current compiler
  started as an experiment, and as a port of a compiler written in Ruby, so its code is not the best Crystal
  code out there.
* **Will you continue working on the current compiler?** Yes and no. We will fix bugs if they are easy to fix,
  and we will continue extending and improving the standard library.
* **Will all my code stop compiling?** Probably. However, you can use the current compiler's `tool hierarchy`
  to ask it the types of instance variables to make the upgrade easier. In fact we might probably include a tool
  to do the upgrade automatically, it's really that simple.
* **Will the new compiler include other features?** We hope so! With this change we also plan to support forwarding
  blocks with the usual `&block` syntax. Right now this is possible but it always ends up creating a closure, but this
  can be done much better. We also plan to allow recursive calls with blocks, something that you can do in Ruby but
  not in Crystal. We also want to be able to have `Array(Object)` or `Array(T)` with any kind of `T`, something that,
  again, is not quite possible with the current version of the language. So these new type annotations will bring a lot
  more power to the language as a compensation.
* **Will there be more breaking changes like this in the future?** We are pretty sure the answer is no. If we know
  the types of instance, class, and global variables then given a method, the type of `self` and the type of its
  arguments we can infer its type by just analyzing that method and the methods it calls. Right now this is not
  possible because the type of some methods depends on how you use a class (what you assign to it). So this change
  will be the last big breaking change.