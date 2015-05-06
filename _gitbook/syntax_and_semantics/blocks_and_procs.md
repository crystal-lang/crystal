# Blocks and Procs

Methods can accept an implicit block of code that can be executed with the `yield` keyword.

```ruby
def twice
  yield
  yield
end

twice do
  puts "Hello!"
end

# Will print:
#
# Hello!
# Hello!
```

Each time you invoke `yield`, the block of code given to the method between the `do ... end` (or `{ .. }`) will be executed.

The block of code has access to the local variables, and can modify them:

```ruby
a = 0
twice do
  a += 1
end
puts a #=> 2
```

In fact, invoking a block of code like this (with `yield`) is exactly the same as manually expanding the invocation (in terms of performance):

```ruby
a = 0
a += 1
a += 1
puts a #=> 2
```

## Block arguments

A block can receive arguments, and these can be given a value by passing arguments to the `yield` keyword:

```ruby
def one_and_three
  yield 1
  yield 3
end

a = 0
one_and_three do |x|
  a += x
end
puts a #=> 4
```

Again, this is exactly the same as writing this:

```ruby
a = 0
a += 1
a += 3
puts a #=> 4
```

You can omit a block's variable if you don't need it:

```ruby
a = 0
one_and_three do
 a += 1
end
puts a
```

If you declare more block variables than the ones passed by `yield`, they will be `nil`:

```ruby
one_and_three do |x, y|
  # here y will always be nil
end
```

## Block and yield values




