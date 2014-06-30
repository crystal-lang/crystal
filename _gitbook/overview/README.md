# Overview

The documentation is divided in three parts:

* The syntax, which resembles Ruby a lot, and its associated semantic
* The built-in types and their built-in methods
* Some common types used across programs and their associated syntax sugar

Everything else in the language is built around these concepts.

You can read this document from the top to the bottom, but it’s advisable to jump through sections because some concepts are related and can’t be explained in isolation.

In code examples, the comment `#=>` is used to show the value of an expression. For example:

``` ruby
a = 1 + 2
a #=> 3
```

A comment using `::` is used for showing the type of a variable.

``` ruby
s = "hello"
# s :: String
```
