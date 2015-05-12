# Proc

A [Proc](http://crystal-lang.org/api/Proc.html) represents a function pointer with an optional context (the closure data). It is typically created with a proc literal:

```ruby
# A proc without arguments
->{ 1 } # Proc(Int32)

# A proc with one argument
->(x : Int32) { x.to_s } # Proc(Int32, String)

# A proc with two arguments:
->(x : Int32, y : Int32) { x + y } # Proc(Int32, Int32, Int32)
```

The types of the arguments are mandatory, except when directly sending a proc literal to a lib `fun` in C bindings.

The return type is inferred from the proc's body.

A special `new` method is provided too:

```ruby
Proc(Int32, String).new { |x| x.to_s } # Proc(Int32, String)
```

This form allows you to specify the return type and to check it against the proc's body.

## Invoking

To invoke a Proc, you invoke the `call` method on it. The number of arguments must match the proc's type:

```ruby
proc = ->(x : Int32, y : Int32) { x + y }
proc.call(1, 2) #=> 3
```

## From methods

A Proc can be created from an existing method:

```ruby
def one
  1
end

proc = ->one
proc.call #=> 1
```

If the method has arguments, you must specify their types:

```ruby
def plus_one(x)
  x + 1
end

proc = ->plus_one(Int32)
proc.call(41) #=> 42
```

A proc can optionally specify a receiver:

```ruby
str = "hello"
proc = ->str.count(Char)
proc.call('e') #=> 1
proc.call('l') #=> 2
```
