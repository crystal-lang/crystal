# Modules

Modules serve two purposes:

* as namespaces for defining other types, methods and constants
* as partial types that can be mixed in other types

An example of a module as a namespace:

```ruby
module Curses
  class Window
  end
end

Curses::Window.new
```

Library authors are advised to put their definitions inside a module to avoid name clashes. The standard library usually doesn't have a namespace as its types and methods are very common, to avoid writing long names.

To use a module as a partial type you use `include` or `extend`.

An `include` makes a type include methods defined in that module as instance methods:

```ruby
module ItemsLength
  def length
    items.length
  end
end

class Items
  include ItemsLength

  def items
    [1, 2, 3]
  end
end

items = Items.new
items.length #=> 3
```

In the above example, it is as if we pasted the `length` method from the module into the `Items` class. The way this really works is by making each type have a list of ancestors, or parents. By default this list starts with the superclass. As modules are included they are **prepended** to this list. When a method is not found in a type it is looked up in this list. When you invoke `super`, the first type in this ancestors list is used.

A `module` can include other modules, so when a method is not found in it it will be looked up in the included modules.

An `extend` makes a type include methods defined in that module as class methods:

```ruby
module SomeLength
  def length
    3
  end
end

class Items
  extend SomeLength
end

Items.length #=> 3
```

Both `include` and `extend` make constants defined in the module available to the including/extending type.

Both of them can be used at the top level to avoid writing a namespace over and over (although the chances of name clashes increase):

```ruby
module SomeModule
  class SomeType
  end

  def some_method
    1
  end
end

include SomeModule

SomeType.new # OK, same as SomeModule::SomeType
some_method  # OK, 1
```

## extend self

A common pattern for modules is `extend self`:

```ruby
module Base64
  extend self

  def encode64(string)
    # ...
  end

  def decode64(string)
    # ...
  end
end
```

In this way a module can be used as a namespace:

```ruby
Base64.encode64 "hello" #=> "aGVsbG8="
```

But also it can be included in the program and its methods can be invoked without a namespace:

```ruby
include Base64

encode64 "hello" #=> "aGVsbG8="
```

For this to be useful the method name should have some reference to the module, otherwise chances of name clashes are high.

A module cannot be instantiated:

```ruby
module Moo
end

Moo.new # undefined method 'new' for Moo:Class
```
