# Closures

Captured blocks and proc literals closure local variables and `self`. This is better understood with an example:

```ruby
x = 0
proc = ->{ x += 1; x }
proc.call #=> 1
proc.call #=> 2
x         #=> 2
```

Or with a proc returned from a method:

```ruby
def counter
  x = 0
  ->{ x += 1; x }
end

proc = counter
proc.call #=> 1
proc.call #=> 2
```

In the above example, even though `x` is a local variable, it was captured by the proc literal. In this case the compiler allocates `x` on the heap and uses it as the context data of the proc to make it work, because normally local variables live in the stack and are gone after a method returns.

## Type of closured variables

The compiler is usually moderately smart about the type of local variables. For example:

```ruby
def foo
  yield
end

x = 1
foo do
  x = "hello"
end
x # :: Int32 | String
```

The compiler knows that after the block, `x` can be Int32 or String (it could know that it will always be String because the method always yields, this will maybe improve in the future).

If `x` is assigned something else after the block, the compiler knows the type changed:

```ruby
x = 1
foo do
  x = "hello"
end
x # :: Int32 | String

x = 'a'
x # :: Char
```

However, if `x` is closured by a proc, the type is always the mixed type of all assignments to it:

```ruby
def capture(&block)
  block
end

x = 1
capture { x = "hello" }

x = 'a'
x # :: Int32 | String | Char
```

This is because the captured block could have been potentially stored in a global, class or instance variable and invoked in a separate thread in between the instructions. The compiler doesn't do an exahustive analysis of this: it just assumes that if a variable is captured by a proc, the time of that proc invocation is unknown.

This also happens with regular proc literals, even if it's evident that the proc wasn't invoked or stored:

```ruby
def capture(&block)
  block
end

x = 1
->{ x = "hello" }

x = 'a'
x # :: Int32 | String | Char
```



