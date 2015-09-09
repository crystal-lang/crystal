# enum

An `enum` declaration inside a `lib` declares a C enum:

```crystal
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

```crystal
X::SomeEnum::One #=> One
```

You can specify the value of a member:

```crystal
lib X
  enum SomeEnum
    Ten = 10
    Twenty = 10 * 2
    ThirtyTwo = 1 << 5
  end
end
```

As you can see, some basic math is allowed for a member value: `+`, `-`, `*`, `/`, `&`, `|`, `<<`, `>>` and `%`.

The type of an enum member is `Int32` by default, even if you specify a different type in a constant value:

```crystal
lib X
  enum SomeEnum
    A = 1_u32
  end
end

X::SomeEnum #=> 1_i32
```

However, you can change this default type:

```crystal
lib X
  enum SomeEnum : Int8
    Zero,
    Two = 2
  end
end

X::SomeEnum::Zero #=> 0_i8
X::SomeEnum::Two  #=> 2_i8
```

You can use an enum as a type in a `fun` argument or `struct` or `union` members:

```crystal
lib X
  enum SomeEnum
    One
    Two
  end

  fun some_fun(value : SomeEnum)
end
```
