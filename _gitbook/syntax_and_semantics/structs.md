# Structs

Instead of defining a type with `class` you can do so with `struct`:

```ruby
struct Point
  property x
  property y

  def initialize(@x, @y)
  end
end
```

The differences between a struct and a class are:
* Invoking `new` on a struct allocates it on the stack instead of the heap
* A struct is [passed by value](http://crystal-lang.org/api/Value.html) while a class is passed by reference
* A struct implicitly inherits from [Struct](http://crystal-lang.org/api/Struct.html), which inherits from [Value](http://crystal-lang.org/api/Value.html). A class implicitly inherits from [Reference](http://crystal-lang.org/api/Reference.html).

A struct can inherit from other structs and can also includes modules. A struct can be generic, just like a class.

A struct is mostly used for performance reasons to avoid lots of small memory allocations when passing small copies might be more efficient.

So how do you choose between a struct and a class? The rule of thumb is that if no instance variable is ever reassigned, i.e. your type is immutable, you can use a struct, otherwise use a class.
