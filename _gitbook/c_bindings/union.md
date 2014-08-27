# union

A `union` declaration inside a `lib` declares a C union:

```ruby
lib U
  union IntOrFloat
    int : Int32
    float : Float64
  end
end
```

To create an instance of a union use `new`:

```ruby
value = U::IntOrFloat.new
```

This allocates the union on the stack.

A C union starts with all its fields set to "zero": integers and floats start at zero, pointers start with an address of zero, etc.

To avoid this initialization you can use `::`:

```ruby
value :: U::IntOrFlaot
value.int #=> some garbage value
```

You can set and get its properties:

```ruby
value = U::IntOrFloat.new
value.int = 1
value.int #=> 1
value.float #=> 4.94066e-324
```

A C union is passed by value (as a copy) to functions and methods, and also passed by value when it is returned from a method:

```ruby
def change_it(value)
  value.int = 1
end

value = U::IntOrFloat.new
change_it value
value.int #=> 0
```
