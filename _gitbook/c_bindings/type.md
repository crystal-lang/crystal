# type

A `type` declaration inside a `lib` declares a C `typedef`:

```ruby
lib X
  type MyInt : Int32
end
```

Unlike C, `Int32` and `MyInt` are not interchangeable:

```ruby
lib X
  type MyInt : Int32

  fun some_fun(value : MyInt)
end

X.some_fun 1 # Error: argument 'value' of 'X#some_fun'
             # must be X::MyInt, not Int32

```

Thus, a `type` declaration is useful for opaque types that are created by the C library you are wrapping. An example of this is the C `FILE` type, which you can obtain with `fopen`.
