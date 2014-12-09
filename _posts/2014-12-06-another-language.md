---
layout: post
title: Another language
summary: What if...
thumbnail: ??
author: asterite
---

Crystal has global type inference. You can program without type annotations except
for a few cases where you are required to do so (generic type arguments).

This is a double-edged sword.

On one side, it's really nice not to have to be explicit about types.
This allows for very quick prototyping, similar to dynamic languages.
You can quickly sketch an idea and evolve it without having to constantly
retype things. This is also very helpful when refactoring and reorganizing
code because the friction is very low. For example, when you extract
a method out of a piece of code you just specify the names of the arguments
and the compiler will take care of figuring out the arguments' types and
the return type. Or you can start using an instance variable right away
by assigning some value to it, without having to declare it first with the
possible types it will hold.

But there are also some downsides to this approach. Let's analyze each of them.

**Code becomes harder to understand and follow**

Some say that without type annotations a code becomes harder to follow. Let's look
at an example.

{% highlight ruby %}
def sum(values)
  count = 0
  values.each do |value|
    count += value
  end
  count
end
{% endhighlight %}

What is the type of `values`? How can one understand this piece of code
without knowing what type it operates on?

When you learned how to program we are sure that at one point you were introduced
to pseudocode. It looks similar to code you would find in real life, only it's
simplified: you can rarely see type annotations there. Type is kind of obvious
in the context it is given. If you add type annotations and other information,
it would make it harder to see the code's intention. Sounds familiar?

In our view, Ruby code is very close to pseudocode. In the above code there are
no type annotations. The algorithm is clear: iterate each of the items in `values`
and add them to a `count` variable. That's it. What's the type of `values`? It
doesn't really matter. All we care about is that it can be iterated (with `each`) and
that it can be summed. Additionally, then name `sum`, `values` and `count` help
in understanding the method's intention and the variables' possible types.

Compare this to some other language where you would have to add some types:

{% highlight ruby %}
interface Iterable<T>
  def each(&block : T ->)
end

interface Addable<T>
  def +(other : T)
end

def sum(values : Iterable<T>) where T : Addable<T>
  count = 0
  values.each do |value|
    count += value
  end
  count
end
{% endhighlight %}

Here we are telling the compiler that there is a type, `Iterable` that has an
`each` method that yields elements of a generic type `T`. Then we also tell the
compiler that there's a type `Addable<T>` that has a method `+` that operates with
values of its same type. Finally, we define the `sum` method to operate on
values that belong to the `Iterable<T>` type, where each `T` implements
`Addable<T>`.

To us, this last code is farther from the pseudocode we had in mind. Also,
there's more code to read and understand.

One possible counter-argument to this is that it now becomes easier to navigate
the code. I want to know how `each` is implemented, or what `Addable` is about, and
I know where to find that. We can't do that with dynamic languages if we don't
have type annotations.

But... wait! Crystal is not a dynamic language. When it finishes compiling it
assigns a type to every variable and method that were used. From that information we can recreate
the code and make it browsable. And, in fact, Crystal has a (very experimental)
tool for that, if you compile your code with `crystal browser file.cr`. This will
open a web browser where you can see the type of variables and navigate methods. So
in our opinion this is not a valid reason here.

This last thing also means that Crystal knows the type of a class' instance variables.
In Ruby you might be looking at some class with a `@foo` instance variable and wonder
what its type is. Don't worry, run `crystal hierarchy file.cr` and you will know the
exact type. This will be mostly useful if you run it in your spec files because these
show a class' usage. And in the future it will be possible to view this
information in a documentation format like RDoc.

**Incremental compilation is not possible**

Because there are no type annotations, the compiler needs to figure out the type
of everything, each time, from scratch. There's no way to compile a module to an
object file, or some other format, and later reuse that information, because there
isn't any (type) information at first glance.

Luckily Crystal's compiler is pretty fast: it takes between 5 and 10 seconds to
compile the whole compiler (just 2.3 seconds of that time is spent in the type
inference phase). For larger programs the time will become bigger, so
we will have to find a solution for this problem.

Another issue is that it is hard to do a [REPL](http://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop).
If code always had type annotations we could generate machine code and not worry
about a variable's type possibly changing, or even a type's instance variables
being created or changed.

Many times we were tempted to give up. "If we require the programmer to add type
annotations in instance variables and methods, incremental compilation and a REPL
might become a reality". "At least the syntax would be pleasant".
Fourtunately, whenever one of us said that, another one replied with a big "NO".

This "NO" has a very strong reason. If we change the language in that direction
we will end up with another language. Crystal is a language where you can leave out
type annotations (mind you: you can add type annotations if you really want to). But
if you are forced to add them, then it will not be Crystal anymore. It will probably
be very similar to one of the existing programming languages. And why would we want
to do that? What would be the benefit of inventing yet another language that is similar
to another language in existence (or maybe being developed)? None. It would be a waste
of time, a duplication of effort.

True, if we don't give up we will face harder challenges. Is incremental compilation
really impossible? Couldn't we think of a similar technique? Is a REPL doable somehow
in this language? Very interesting questions arise. Challenging problems appear. Fun
times come.

We believe a language where type annotations are not required from the compiler's part,
but where types are still there, is possible. We want a smart compiler. We don't want
to simplify the language to make our job, compiler writers, easier. We want to make
programmers work easier. And fun :-)
