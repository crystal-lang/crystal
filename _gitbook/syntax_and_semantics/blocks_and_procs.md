# Blocks and Procs

Methods can accept a block of code that is executed
with the `yield` keyword. For example:

```ruby
def twice
  yield
  yield
end

twice do
  puts "Hello!"
end
```

The above program prints "Hello!" twice, once for each `yield`.

To define a method that receives a block, simply use `yield` inside it and the compiler will know. You can make this more evident by declaring a dummy block argument, indicated as a last argument prefixed with ampersand (`&`):

```ruby
def twice(&block)
  yield
  yield
end
```

To invoke a method and pass a block, you use `do ... end` or `{ ... }`. All of these are equivalent:

```ruby
twice() do
  puts "Hello!"
end

twice do
  puts "Hello!"
end

twice { puts "Hello!" }
```

## Overloads

Two methods, one that yields and another that doesn't, are considered different overloads, as explained in the [overloading](overloading.html) section.

## Yield arguments

The `yield` expression is similar to a call and can receive arguments. For example:

```ruby
def twice
  yield 1
  yield 2
end

twice do |i|
  puts "Got #{i}"
end
```

The above prints "Got 1" and "Got 2".

A curly braces notation is also available:

```ruby
twice { |i| puts "Got #{i}" }
```

You can `yield` many values:

```ruby
def many
  yield 1, 2, 3
end

many do |x, y, z|
  puts x + y + z
end

# Output: 6
```

A block can specify less than the arguments yielded:

```ruby
def many
  yield 1, 2, 3
end

many do |x, y|
  puts x + y
end

# Output: 3
```

A block can also specify more than the arguments yielded, and these will be `nil`:

```ruby
def twice
  yield
  yield
end

twice do |i|
  puts i.inspect
end
```

The above outputs "nil" twice.

Each block variable has the type of every yield expression in that position. For example:

```ruby
def some
  yield 1, 'a'
  yield true, "hello"
  yield 2
end

some do |first, second|
  # first is Int32 | Bool
  # second is Char | String | Nil
end
```

The block variable `second` also includes the `Nil` type because the last `yield` expression didn't include a second argument.

## yield value

The `yield` expression itself has a value: the last expression of the block. For example:

```ruby
def twice
  v1 = yield 1
  puts v1

  v2 = yield 2
  puts v2
end

twice do |i|
  i + 1
end
```

The above prints "2" and "3".

A `yield` expression's value is mostly useful for transforming and filtering values. The best examples of this are [Enumerable#map](http://crystal-lang.org/api/Enumerable.html#map%28%26block%20%3A%20T%20-%3E%20U%29-instance-method) and [Enumerable#select](http://crystal-lang.org/api/Enumerable.html#select%28%26block%20%3A%20T%20-%3E%20%29-instance-method):

```ruby
ary = [1, 2, 3]
ary.map { |x| x + 1 }         #=> [2, 3, 4]
ary.select { |x| x % 2 == 1 } #=> [1, 3]
```

A dummy transformation method:

```ruby
def transform(value)
  yield value
end

transform(1) { |x| x + 1 } #=> 2
```

The result of the last expression is `2` because the last expression of the `transform` method is `yield`, whose value is the last expression of the block.

## break

A `break` expression inside a block exits early from the method:

```ruby
def thrice
  puts "Before 1"
  yield 1
  puts "Before 2"
  yield 2
  puts "Before 3"
  yield 3
  puts "After 3"
end

thrice do |i|
  if i == 2
    break
  end
end
```

The above prints "Before 1" and "Before 2". The `thrice` method didn't execute the `puts "Before 3"` expression because of the `break`.

`break` can also accept arguments: these become the method's return value. For example:

```ruby
def twice
  yield 1
  yield 2
end

twice { |i| i + 1 } #=> 3
twice { |i| break "hello" } #=> "hello"
```

The first call's value is 3 because the last expression of the `twice` method is `yield`, which gets the value of the block. The second call's value is "hello" because a `break` was performed.

If there are conditional breaks, the call's return value type will be a union of the type of the block's value and the type of the many `break`s:

```ruby
value = twice do |i|
  if i == 1
    break "hello"
  end
  i + 1
end
value #:: Int32 | String
```

If a `break` receives many arguments, they are automatically transformed to a [Tuple](http://crystal-lang.org/api/Tuple.html):

```ruby
values = twice { break 1, 2 }
values #=> {1, 2}
```

If a `break` receives no arguments, it's the same as receiving a single `nil` argument:

```ruby
value = twice { break }
value #=> nil
```

## next

The `next` expression inside a block exits early from the block (not the method). For example:

```ruby
def twice
  yield 1
  yield 2
end

twice do |i|
  if i == 1
    puts "Skipping 1"
    next
  end

  puts "Got #{i}"
end

# Ouptut:
# Skipping 1
# Got 2
```

The `next` expression accepts arguments, and these give the value of the `yield` expression that invoked the block:

```ruby
def twice
  v1 = yield 1
  puts v1

  v2 = yield 2
  puts v2
end

twice do |i|
  if i == 1
    next 10
  end

  i + 1
end

# Output
# 10
# 3
```

If a `next` receives many arguments, they are automaticaly transformed to a [Tuple](http://crystal-lang.org/api/Tuple.html). If it receives no arguments it's the same as receiving a single `nil` argument.

## with ... yield

A `yield` expression can be modified, using the `with` keyword, to specify an object to use as the default receiver of method calls within the block:

```ruby
class Foo
  def one
    1
  end

  def yield_with_self
    with self yield
  end

  def yield_normally
    yield
  end
end

def one
  "one"
end

Foo.new.yield_with_self { one } # => 1
Foo.new.yield_normally { one }  # => "one"
```

## Performance

When using blocks with `yield`, the blocks are **always** inlined: no closures, calls or function pointers are involved. This means that this:

```ruby
def twice
  yield 1
  yield 2
end

twice do |i|
  puts "Got: #{i}"
end
```

is exactly the same as writing this:

```ruby
i = 1
puts "Got: #{i}"
i = 2
puts "Got: #{i}"
```

For example, the standard library includes a `times` method on integers, allowing you to write:

```ruby
3.times do |i|
  puts i
end
```

This looks very fancy, but is it as fast as a C for loop? The answer is: yes!

This is `Int#times` definition:

```ruby
struct Int
  def times
    i = 0
    while i < self
      yield i
      i += 1
    end
  end
end
```

Because a non-captured block is always inlined, the above method invocation is **exactly the same** as writing this:

```ruby
i = 0
while i < 3
  puts i
  i += 1
end
```

Have no fear using blocks for readability or code reuse, it won't affect the resulting executable performance.
