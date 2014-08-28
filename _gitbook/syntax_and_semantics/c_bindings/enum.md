# enum

An `enum` declaration inside a `lib` declares a C enum:

```ruby
lib X
  # In C:
  #
  #  enum SomeEnum {
  #    Zero,
  #    One,
  #    Two,
  #    Three,
  #  };
  enum SomeEnum
    Zero
    One
    Two
    Three
  end
end
```

As in C, the first member of the enum has a value of zero and each successive value is incremented by one.

To use a value:

```ruby
X::SomeEnum::One #=> 1
```

You can specify the value of a member:

```ruby
lib X
  enum SomeEnum
    Ten = 10
    Twenty = 10 * 2
    ThirtyTwo = 1 << 5
  end
end
```

As you can see, some basic math is allowed for a member value: `+`, `-`, `*`, `/`, `&`, `|`, `<<`, `>>` and `%`.

The type of an enum member is `Int32` by defualt, but you can change it:

```ruby
lib X
  enum SomeEnum < Int8
    Zero
  end
end

X::SomeEnum::Zero #=> 1_i8
```

You can use an enum as a type in a `fun` argument or `struct` or `union` members:

```ruby
lib X
  enum SomeEnum
    One
    Two
  end

  fun some_fun(value : SomeEnum)
end
```

Doing so is exactly the same as using the enum's underlying type (`Int32` in the above example), only that the intent is a bit clearer.
