---
layout: post
title: Type inference (part 2)
author: bcardiff
---

Previously on part 1 we saw the very basics of how the type inference algorithm work at block level.

The next step is to introduce functions. _defs_ in crystal don't need to have type annotations. So a programmer could write the following:

{% highlight ruby %}
def dup(x)
  x + x
end
{% endhighlight ruby %}

`dup` definition does not generates any program by itself. Only when it is called the body is analyzed. Also, each time `dup` is called it could end up calling actualy different versions of the compiled function. Wait... What? You could see every def as a _C++ template function_. At every invoke, thanks to the context information of the arguments the type inference (and the codegen later) will find or create a _typed def_. So each _typed def_ could be seen as a _C++ overload_.

A _typed def_ is an specialization of the original _def_ for a given types of arguments. The next code use `dup` both for `String` and `Int32`.

{% highlight ruby %}
def dup(x)
  x + x
end

a = "Hip!"
b = dup(a)

n = 1
m = dup(n)
{% endhighlight ruby %}

<hr>

*Did you know?* `/bin/crystal sample.cr -types` will show the types of the top variables?

<pre class="code">
$ ./bin/crystal sample.cr -types
a : String
b : String
n : Int32
m : Int32
</pre>

*Did you know?* `/bin/crystal sample.cr --html ./types` will create html files that allow you to digg into the output of the compiler?

<pre class="code">
$ ./bin/crystal sample.cr --html types
$ open ./types/main.html
</pre>

<hr>

So, a method call is represented by a AST node that initially holds just the name of the method. When the arguments begin to receive type information due to the dependency bindings that are built, a lookup for a `typed def` begins.

The type inference continue to run in the context of the method body, and the type of the result is binded to the caller AST node so the story can follows.

Let me add something else before we jump into a graph of type dependency between AST nodes.

There is cache of _typed defs_ that allow to reuse them **if the types of the arguments** match. This allow crystal to deal with recursive and mutual recursive functions.

We will continue with a mutual recursive example to compute parity of a number.

{% highlight ruby %}
def even(x)
  if x == 0
    true
  else
    odd(x-1)
  end
end

def odd(x)
  if x == 0
    false
  else
    even(x-1)
  end
end

p = even(7)
{% endhighlight ruby %}


