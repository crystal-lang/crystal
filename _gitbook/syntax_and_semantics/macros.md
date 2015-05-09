# Macros

Macros are methods that receive AST nodes at compile-time and produce
code that is pasted into a program. For example:

```ruby
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

## Interpolation

You use `{{...}}` to paste, or interpolate, an AST node, as in the above example.

Note that the node is pasted as-is. If in the previous example we pass a symbol, the generated code becomes invalid:

```ruby
# This generates:
#
#     def :foo
#       1
#     end
define_method :foo, 1
```

Note that `:foo` was the result of the interpolation, because that's what was passed to the macro. You can use the method `ASTNode#id` in these cases, where you just need an identifier.

## Macro calls

You can invoke a **fixed subset** of methods on AST nodes at compile-time. These methods are documented in a ficticious [Macros](http://crystal-lang.org/api/Macros.html) module.

For example, invoking `ASTNode#id` in the above example solves the problem:

```ruby
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

```ruby
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

```ruby
{% if env("TEST") %}
  puts "We are in test mode"
{% end %}
```

### Iteration
To iterate an `ArrayLiteral`:

```ruby
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

```ruby
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

```ruby
{% for name, index in ["foo", "bar", "baz"] %}
  def {{name.id}}
    {{index}}
  end
{% end %}

foo #=> 1
bar #=> 2
baz #=> 3
```

## Variadic arguments and splatting

A macro can accept variadic arguments:

```ruby
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

Additionaly, using `*` when interpolating an `ArrayLiteral` interpolates the elements separated by commas:

```ruby
macro println(*values)
   print {{*values}}, '\n'
end

println 1, 2, 3 # outputs 123\n
```

### Fresh variables

Once macros generate code, they are parsed with a regular Crystal parser where local variables in the context of the macro invocations are assumed to be defined.

This is better understood with an example:

```ruby
macro update_x
  x = 1
end

x = 0
update_x
x #=> 1
```

This can sometimes be useful to avoid repetitive code by actually accessing and reading/writing local varaibles, but can also overwrite local variables by mistake. You can use fresh variables with `%name`:

```ruby
macro dont_update_x
  %x = 1
  puts %x
end

x = 0
dont_update_x # outputs 1
x #=> 0
```

Using `%x` in the above example we declare a variable whose name is guaranteed not to conflict with local varaibles in the current scope.

Additionally, you can declare fresh variables related to some other AST node using `%var{key1, key2, ..., keyN}`. For example:

```ruby
macro fresh_vars_sample(*names)
  # First declare vars
  {% for name, index in names %}
    print "Declaring: ", "%name{index}", '\n'
    %name{index} = {{index}}
  {% end %}

  # Then print them
  {% for name, index in names %}
    print "%name{index}: ", %name{index}, '\n'
  {% end %}
end

fresh_vars_sample

# Sample output:
# Declaring: __temp_255
# Declaring: __temp_256
# Declaring: __temp_257
# __temp_255: 0
# __temp_256: 1
# __temp_257: 2
```

In the above example three variables were declared, associated to an index, and then they were printed, refering to these variables with the same indices.

### Type information

When a macro is invoked you can access the current scope, or type, with a special instance variable: `@type`. The type of this variable is `TypeNode`, which gives you access to type information at compile time.

Note that `@type` is always the *instance* type, even when the macro is invoked in a class method.

### Constants

Macros can access constants. For example:

```ruby
VALUES = [1, 2, 3]

{% for value in VALUES %}
  puts {{value}}
{% end %}
```

If the constant denotes a type, you get back a `TypeNode`.

### Macro defs

Macro defs allow you to define a method for a class hierarchy and have that method be evaluated at the end of the type-inference phase, as a macro, where type information is known, for each concrete subtype. For example:

```ruby
class Object
  macro def instance_vars_names : Array(String)
    {{ @type.instance_vars.map &.name }}
  end
end

class Person
  def initialize(@name, @age)
  end
end

person = Person.new "John", 30
person.instance_vars_names #=> ["name", "age"]
```

Note that in the case of macro defs you need to specify the return type.

### Macro hooks

Special macros exist that are invoked in some situations, as hooks:
`inherited`, `included` and `method_missing`.
* `inherited` will be invoked at compile-time when a subclass is defined. `@type` becomes the inherited type.
* `included` will be invoked at compile-time when a module is included. `@type` becomes the including type.
* `method_missing` will be invoked at compile-time when a method is not found.

Example of `inherited`:

```ruby
class Parent
  macro inherited
    def {{@type.name.downcase.id}}
      1
    end
  end
end

class Child1 < Parent
end

Child.new.child #=> 1
```

Example of `method_missing`:

```ruby
macro method_missing(name, args, block)
  print "Got ", {{name.id.stringify}}, " with ", {{args.length}}, " arguments", '\n'
end

foo          # Prints: Got foo with 0 arguments
bar 'a', 'b' # Prints: Got bar with 2 arguments
```
