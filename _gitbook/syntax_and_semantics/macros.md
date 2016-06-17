# Macros

Macros are methods that receive AST nodes at compile-time and produce
code that is pasted into a program. For example:

```crystal
macro define_method(name, content)
  def {{name}}
    {{content}}
  end
end

# This generates:
#
#     def foo
#       1
#     end
define_method foo, 1

foo #=> 1
```

A macro's definition body looks like regular Crystal code with
extra syntax to manipulate the AST nodes. The generated code must
be valid Crystal code, meaning that you can't for example generate
a `def` without a matching `end`, or a single `when` expression of a
`case`, since both of them are not complete valid expressions.

## Scope

Macros declared at the top-level are visible anywhere. If a top-level macro is marked as `private` it is only accessible in that file.

They can also be defined in classes and modules, and are visible in those scopes. Macros are also looked-up in the ancestors chain (superclasses and included modules).

For example, a block which is given an object to use as the default receiver by being invoked with `with ... yield` can access macros defined within that object's ancestors chain:

```crystal
class Foo
  macro emphasize(value)
    "***#{ {{value}} }***"
  end

  def yield_with_self
    with self yield
  end
end

Foo.new.yield_with_self { emphasize(10) } #=> "***10***"
```

Macros defined in classes and modules can be invoked from outside of them too:

```crystal
class Foo
  macro emphasize(value)
    "***#{ {{value}} }***"
  end
end

Foo.emphasize(10) # => "***10***"
```

## Interpolation

You use `{{...}}` to paste, or interpolate, an AST node, as in the above example.

Note that the node is pasted as-is. If in the previous example we pass a symbol, the generated code becomes invalid:

```crystal
# This generates:
#
#     def :foo
#       1
#     end
define_method :foo, 1
```

Note that `:foo` was the result of the interpolation, because that's what was passed to the macro. You can use the method `ASTNode#id` in these cases, where you just need an identifier.

## Macro calls

You can invoke a **fixed subset** of methods on AST nodes at compile-time. These methods are documented in a fictitious [Crystal::Macros](http://crystal-lang.org/api/Crystal/Macros.html) module.

For example, invoking `ASTNode#id` in the above example solves the problem:

```crystal
macro define_method(name, content)
  def {{name.id}}
    {{content}}
  end
end

# This correctly generates:
#
#     def foo
#       1
#     end
define_method :foo, 1
```

## Conditionals

You use `{% if condition %}` ... `{% end %}` to conditionally generate code:

```crystal
macro define_method(name, content)
  def {{name}}
    {% if content == 1 %}
      "one"
    {% else %}
      {{content}}
    {% end %}
  end
end

define_method foo, 1
define_method bar, 2

foo #=> one
bar #=> 2
```

Similar to regular code, `Nop`, `NilLiteral` and a false `BoolLiteral` are considered *falsey*, while everything else is considered truthy.

Macro conditionals can be used outside a macro definition:

```crystal
{% if env("TEST") %}
  puts "We are in test mode"
{% end %}
```

### Iteration
To iterate an `ArrayLiteral`:

```crystal
macro define_dummy_methods(names)
  {% for name, index in names %}
    def {{name.id}}
      {{index}}
    end
  {% end %}
end

define_dummy_methods [foo, bar, baz]

foo #=> 0
bar #=> 1
baz #=> 2
```

The `index` variable in the above example is optional.

To iterate a `HashLiteral`:

```crystal
macro define_dummy_methods(hash)
  {% for key, value in hash %}
    def {{key.id}}
      {{value}}
    end
  {% end %}
end
define_dummy_methods({foo: 10, bar: 20})
foo #=> 10
bar #=> 20
```

Macro iterations can be used outside a macro definition:

```crystal
{% for name, index in ["foo", "bar", "baz"] %}
  def {{name.id}}
    {{index}}
  end
{% end %}

foo #=> 0
bar #=> 1
baz #=> 2
```

## Variadic arguments and splatting

A macro can accept variadic arguments:

```crystal
macro define_dummy_methods(*names)
  {% for name, index in names %}
    def {{name.id}}
      {{index}}
    end
  {% end %}
end

define_dummy_methods foo, bar, baz

foo #=> 0
bar #=> 1
baz #=> 2
```

The arguments are packed into an `ArrayLiteral` and passed to the macro.

Additionally, using `*` when interpolating an `ArrayLiteral` interpolates the elements separated by commas:

```crystal
macro println(*values)
   print {{*values}}, '\n'
end

println 1, 2, 3 # outputs 123\n
```

### Type information

When a macro is invoked you can access the current scope, or type, with a special instance variable: `@type`. The type of this variable is `TypeNode`, which gives you access to type information at compile time.

Note that `@type` is always the *instance* type, even when the macro is invoked in a class method.

### Constants

Macros can access constants. For example:

```crystal
VALUES = [1, 2, 3]

{% for value in VALUES %}
  puts {{value}}
{% end %}
```

If the constant denotes a type, you get back a `TypeNode`.
