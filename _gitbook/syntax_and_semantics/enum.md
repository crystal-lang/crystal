# Enums

An enum is a set of integer values, where each value has an associated name. For example:

```ruby
enum Color
  Red
  Green
  Blue
end
```

An enum is defined with the `enum` keyword, followed by its name. The enum's body contains the values. Values start with the value `0` and are incremented by one. The default value can be overwritten:

```ruby
enum Color
  Red         # 0
  Green       # 1
  Blue   = 5  # overwritten to 5
  Yellow      # 6 (5 + 1)
end
```

Each constant in the enum has the type of the enum:

```ruby
Color::Red #:: Color
```

To get the underlying value you invoke `value` on it:

```ruby
Color::Green.value #=> 1
```

The type of the value is `Int32` by default but can be changed:

```ruby
enum Color : UInt8
  Red
  Green
  Blue
end

Color::Red.value #:: UInt8
```

Only integer types are allowed as the underlying type.

All enums inherit from [Enum](http://crystal-lang.org/api/Enum.html).

## Flags enums

An enum can be marked with the `@[Flags]` attribute. This changes the default values:

```ruby
@[Flags]
enum IOMode
  Read # 1
  Write  # 2
  Async # 4
end
```

The `@[Flags]` attribute makes the first constant's value be `1`, and successive constants are multiplied by `2`.

Implicit constants, `None` and `All`, are automatically added to these enums, where `None` has the value `0` and `All` has the "or"ed value of all constants.

```ruby
IOMode::None.value #=> 0
IOMode::All.value  #=> 7
```

Additionally, some `Enum` methods check the `@[Flags]` method. For example:

```ruby
puts(Color::Red)                    # prints "Red"
puts(IOMode::Write | IOMode::Async) # prints "Write, Async"
```

## Enums from integers

An enum can be created from an integer:

```ruby
puts Color.new(1) #=> prints "Green"
```

Values that don't correspond to an enum's constants are allowed: the value will still be of type `Color`, but when printed you will get the underlying value:

```ruby
puts Color.new(10) #=> prints "10"
```

This method is mainly intended to convert integers from C to enums in Crystal.

## Methods

Just like a class or a struct, you can define methods for enums:

```ruby
enum Color
  Red
  Green
  Blue

  def red?
    self == Color::Red
  end
end

Color::Red.red?  #=> true
Color::Blue.red? #=> false
```

Class variables are allowed, but instance variables not.

## Usage

Enums are a type-safe alternative to [Symbol](http://crystal-lang.org/api/Symbol.html). For example, an API's method can specify a [type restriction](type_restrictions.html) using an enum type:

```ruby
def paint(color : Color)
  case color
  when Color::Red
    # ...
  else
    # Unusual, but still can happen
    raise "unknown color: #{color}"
  end
end

paint Color::Red
```

The above could also be implemented with a Symbol:

```ruby
def paint(color : Symbol)
  case color
  when :red
    # ...
  else
    raise "unknown color: #{color}"
  end
end

paint :red
```

However, if the programmer makes a typo, say `:reed`, the error will only be caught at runtime, but writing `Color::Reed` will result in a compile-time error.

The recommended thing to do is to use enums whenever possible, only use symbols for the internal implementation of an API, and avoid symbols for public APIs. But you are free to do what you want.
