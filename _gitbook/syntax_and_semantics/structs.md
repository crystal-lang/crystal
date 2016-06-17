# Structs

Instead of defining a type with `class` you can do so with `struct`:

```crystal
struct Point
  property x, y

  def initialize(@x : Int32, @y : Int32)
  end
end
```

The differences between a struct and a class are:
* Invoking `new` on a struct allocates it on the stack instead of the heap
* A struct is [passed by value](http://crystal-lang.org/api/Value.html) while a class is passed by reference
* A struct implicitly inherits from [Struct](http://crystal-lang.org/api/Struct.html), which inherits from [Value](http://crystal-lang.org/api/Value.html). A class implicitly inherits from [Reference](http://crystal-lang.org/api/Reference.html).
* A struct cannot inherit a non-abstract struct.

The last point has a reason to it: a struct has a very well defined memory layout. For example, the above `Point` struct occupies 8 bytes. If you have an array of points the points are embedded inside the array's buffer:

```crystal
# The array's buffer will have each 8 bytes dedicated to each Point
ary = [] of Point
```

If `Point` is inherited, an array of such type must also account for the fact that other types can be inside it, so the size of each element must grow to accommodate that. That is certainly unexpected. So, non-abstract structs can't be inherited. Abstract structs, on the other hand, will have descendants, so it's expected that an array of them will account the possibility of having multiple types inside it.

A struct can also includes modules and can be generic, just like a class.

A struct is mostly used for performance reasons to avoid lots of small memory allocations when passing small copies might be more efficient.

So how do you choose between a struct and a class? The rule of thumb is that if no instance variable is ever reassigned, i.e. your type is immutable, you could use a struct, otherwise use a class.
