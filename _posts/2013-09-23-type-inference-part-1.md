---
layout: post
title: Type inference (part 1)
thumbnail: x=
summary: How type inference works
author: bcardiff
---

Type inference is a feature every programmer should love. It keep the programmer out of specifying types in the code, and is just so nice.

Here we try to explain the basis on how Crystal infers types of a program. Also aim for a little documentation on how to understand the [type_inference](https://github.com/manastech/crystal/blob/master/src/compiler/crystal/type_inference.cr).

Like most type inference algorithms, the explanation is guided by the AST. Each AST node will have an associated type which corresponds to the type of the expression.

The whole program AST is traversed while the type inference binds AST nodes in order to mimic the deductions a programmer would make to discover the types.

**Literals**

These are easy. Booleans, numbers, chars and values that are explicitly written have the type determined directly by syntax.

{% highlight ruby %}
true # :: Boolean
1    # :: Int32
{% endhighlight ruby %}

**Variables**

Compiler needs to know the type of each variable. Variables also have a context where they can be evaluated.

Type inference algorithm register on each context which variables exist. So compiler would be able to declare them explicitly.

The very basic statement that determines the type of a variable is an assigment.

{% highlight ruby %}
v = true
{% endhighlight ruby %}

The AST node of the assignement has 1) a target (left hand side), 2) an expression (right hand side). When the type of the rhs is determined, the type inference algorithm states that the lhs should be able to store a value of that type.

Instead of computing it in a backtracking fashion (in order to support more complex scenarios) the algorithm works by building a graph of dependencies over the AST nodes.

The next picture shows the AST nodes, the context where the variables and their types are hold, and blue arrows that highlight the type dependency between parts.

<img src="/images/type-inference/assign-variable.png" width="374" height="203" class="center"/>

**Conditionals (a.k.a. Ifs)**

Crystal supports [union types](http://en.wikipedia.org/wiki/Union_type). When a variable is assigned multiple times in the same context (but in different branches) its expected type is the one that can handle all the assignments. So if the following code is given:

{% highlight ruby %}
if false
  v = false
else
  v = 2
end
{% endhighlight ruby %}

At the end of it `v` should be of type `Int32 | Boolean`.

Once more, we show the AST nodes, the context where the variables and their types are hold, and blue arrows that highlight the type dependency between parts.

<img src="/images/type-inference/conditional-1.png" width="562" height="324" class="center"/>

When a new type arrives to the variable in the context, this is added to the "ongoing" known types. So the union appears.

There is one thing that is not shown still. *Every* ocurrence of the variables have a dependency to the context. This is shown in the following picture:

<img src="/images/type-inference/conditional-2.png" width="563" height="325" class="center"/>

This way, each assignment knows that it is aimed to assign a `Boolean` to a `Int32 | Boolean` or `Int32` to `Int32 | Boolean`. This information is used in the codegen.

