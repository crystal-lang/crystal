# Macros

Macros allow generating code at compile time.

For example, this is the source code of the `getter` macro:

``` ruby
macro getter(name)
  def {{name.id}}
    @{{name.id}}
  end
end

class Person
  # Expands to:
  #
  #   def name
  #     @name
  #   end
  getter :name
end
```

To understand the simple macro above we need to understand what's inside a `macro`'s body, what are its arguments and what we can do with them.

A `macro`'s body consists of a sequence of characters that can contain macro interpolations (`{{...}}`) and macro controls (`{% ... %}`). This is a perfectly valid macro:

``` ruby
macro foo(really)
  I can write whataver I want here (well... not {{really}})
end
```

This means that a `macro`'s body is not parsed using a regular Crystal parser. This also means that you can use macro interpolations and macro controls anywhere inside a `macro`'s body, which gives you greater flexibility.

So how does Crystal know when a macro ends? Well, it counts the opening and endings. Examples of openings are `def`, `class`, `if`. The only ending is `end`. This rule is because you will probably want to generate Crystal code with macros. Remmeber this rule, because it will allow you to trick the macro parser for your benefit:

``` ruby
macro define_foo(kind)
  {{kind.id}} Foo

  # We can't use a simple "end", because Crystal will think
  # the macro ends here
  {{:end.id}}
end

define_foo :struct
```

(don't worry, you will almost never have to do something like the above)

Macros are executed at compile time, and receive [AST nodes](http://en.wikipedia.org/wiki/Abstract_syntax_tree). By applying macro interpolations and controls they evaluate them to a string. This string must be parsed to a valid Crystal program.

So, in the `getter` example, the macro receives a `SymbolLiteral` node. If we consider this alternative definition:

``` ruby
macro getter(name)
  def {{name}}
    @{{name}}
  end
end

# Generates:
#
#   def :name
#     @:name
#   end
getter :name
```

We can see that the result we got is not what we expected. This is because we pasted the `SymbolLiteral` in the macro, and as we can see in the `getter :name` invocation, it contains a colon (`:`) before it.

To get rid of the colon, we can invoke `id` on it before interpolating it:

``` ruby
macro getter(name)
  def {{name.id}}
    @{{name.id}}
  end
end

# Generates:
#
#   def name
#     @name
#   end
getter :name
```

The `id` method in macros gets rid of the colon from symbol literals and gets rid of the quotes from string literals. For other kind of AST nodes it has no effect (returns the same node). This means we can also invoke `getter` like this:

``` ruby
getter "name"
```

And also like this:

``` ruby
getter name
```

This is because macro arguments are never evaluated, so it doesn't matter what `name` means here: for the macro it will only be some AST node.
