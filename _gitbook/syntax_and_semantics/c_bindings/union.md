# union

A `union` declaration inside a `lib` declares a C union:

```crystal
lib U
  # In C:
  #
  #  union IntOrFloat {
  #    int some_int;
  #    double some_float;
  #  };
  union IntOrFloat
    some_int : Int32
    some_float : Float64
  end
end
```

To create an instance of a union use `new`:

```crystal
value = U::IntOrFloat.new
```

This allocates the union on the stack.

A C union starts with all its fields set to "zero": integers and floats start at zero, pointers start with an address of zero, etc.

To avoid this initialization you can use `uninitialized`:

```crystal
value = uninitialized U::IntOrFlaot
value.some_int #=> some garbage value
```

You can set and get its properties:

```crystal
value = U::IntOrFloat.new
value.some_int = 1
value.some_int #=> 1
value.some_float #=> 4.94066e-324
```

If the assigned value is not exactly the same as the property's type, [to_unsafe](to_unsafe.html) will be tried.

A C union is passed by value (as a copy) to functions and methods, and also passed by value when it is returned from a method:

```crystal
def change_it(value)
  value.some_int = 1
end

value = U::IntOrFloat.new
change_it value
value.some_int #=> 0
```

Refer to the [type grammar](../type_grammar.html) for the notation used in union field types.
