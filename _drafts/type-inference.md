---
layout: post
title: Type inference
author: bcardiff
---

Type inference is a feature every programer should love. It keep the programer out of specifying types in the code, and is just so nice.

Here we try to explain the basis on how Crystal infers types of the program.

Like most type inference algorithms, the explanation is guided by the AST. Each AST node will have an associated type, which corresponds to the type of the expression.

The whole program AST is traversed while the type inference tight AST nodes to mimic the deductions a programmer would make to discover the types.

**Literals**

These are easy. Booleans, numbers, chars and values that are explicitly written have the type determined directly by syntax.

{% highlight ruby %}
true # :: Boolean
1 # :: Int32
{% endhighlight ruby %}

**Variables**

Compiler needs to know the type of each variable. Variables also have a context where them can be evaluated.

Type inference algorithm register on each context which variables exists. So compiler would be able to declare them explicitly.

The very basic statement that determines the type of a variable is an assigment.

{% highlight ruby %}
v = true
{% endhighlight ruby %}

The AST node of the assignement has 1) a target (left hand side), 2) an expression (right hand side). When the type of the rhs is determined, the type inference algorithm stands that the lhs should be able to store a value of that type.

Instead of computing it in a backtracking fashion (in order to support more complex scenarios) the algorithm works by building a graph of dependencies over the AST nodes.

The next picture shows the AST nodes, the context where the variables, their types are hold, and blue arrows that highlight the type dependency between parts.

![](/images/type-inference/assign-variable.png)
