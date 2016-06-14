# Blocks and Procs

Methods can accept a block of code that is executed
with the `yield` keyword. For example:

```crystal
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

```crystal
def twice(&block)
  yield
  yield
end
```

To invoke a method and pass a block, you use `do ... end` or `{ ... }`. All of these are equivalent:

```crystal
twice() do
  puts "Hello!"
end

twice do
  puts "Hello!"
end

twice { puts "Hello!" }
```

The difference between using `do ... end` and `{ ... }` is that `do ... end` binds to the left-most call, while `{ ... }` binds to the right-most call:

```crystal
foo bar do
  something
end

# The above is the same as
foo(bar) do
  something
end

foo bar { something }

# The above is the same as

foo(bar { something })
```

The reason for this is to allow creating Domain Specific Languages (DSLs) using `do ... end` to have them be read as plain English:

```crystal
open file "foo.cr" do
  something
end

# Same as:
open(file("foo.cr")) do
end
```

You wouldn't want the above to be:

```crystal
open(file("foo.cr") do
end)
```

## Overloads

Two methods, one that yields and another that doesn't, are considered different overloads, as explained in the [overloading](overloading.html) section.

## Yield arguments

The `yield` expression is similar to a call and can receive arguments. For example:

```crystal
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

```crystal
twice { |i| puts "Got #{i}" }
```

You can `yield` many values:

```crystal
def many
  yield 1, 2, 3
end

many do |x, y, z|
  puts x + y + z
end

# Output: 6
```

A block can specify less than the arguments yielded:

```crystal
def many
  yield 1, 2, 3
end

many do |x, y|
  puts x + y
end

# Output: 3
```

It's an error specifying more block arguments than those yielded:

```crystal
def twice
  yield
  yield
end

twice do |i| # Error: too many block arguments
end
```

Each block variable has the type of every yield expression in that position. For example:

```crystal
def some
  yield 1, 'a'
  yield true, "hello"
  yield 2, nil
end

some do |first, second|
  # first is Int32 | Bool
  # second is Char | String | Nil
end
```

The block variable `second` also includes the `Nil` type because the last `yield` expression didn't include a second argument.

## Short one-argument syntax

A short syntax exists for specifying a block that receives a single argument and invokes a method on it. This:

```crystal
method do |argument|
  argument.some_method
end
```

Can be written as this:

```crystal
method &.some_method
```

Or like this:

```crystal
method(&.some_method)
```

The above is just syntax sugar and doesn't have any performance penalty.

Arguments can be passed to `some_method` as well:

```crystal
method &.some_method(arg1, arg2)
```

And operators can be invoked too:

```crystal
method &.+(2)
method &.[index]
```

## yield value

The `yield` expression itself has a value: the last expression of the block. For example:

```crystal
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

```crystal
ary = [1, 2, 3]
ary.map { |x| x + 1 }         #=> [2, 3, 4]
ary.select { |x| x % 2 == 1 } #=> [1, 3]
```

A dummy transformation method:

```crystal
def transform(value)
  yield value
end

transform(1) { |x| x + 1 } #=> 2
```

The result of the last expression is `2` because the last expression of the `transform` method is `yield`, whose value is the last expression of the block.

## break

A `break` expression inside a block exits early from the method:

```crystal
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

```crystal
def twice
  yield 1
  yield 2
end

twice { |i| i + 1 } #=> 3
twice { |i| break "hello" } #=> "hello"
```

The first call's value is 3 because the last expression of the `twice` method is `yield`, which gets the value of the block. The second call's value is "hello" because a `break` was performed.

If there are conditional breaks, the call's return value type will be a union of the type of the block's value and the type of the many `break`s:

```crystal
value = twice do |i|
  if i == 1
    break "hello"
  end
  i + 1
end
value #:: Int32 | String
```

If a `break` receives many arguments, they are automatically transformed to a [Tuple](http://crystal-lang.org/api/Tuple.html):

```crystal
values = twice { break 1, 2 }
values #=> {1, 2}
```

If a `break` receives no arguments, it's the same as receiving a single `nil` argument:

```crystal
value = twice { break }
value #=> nil
```

## next

The `next` expression inside a block exits early from the block (not the method). For example:

```crystal
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

```crystal
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

```crystal
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

## Unpacking block arguments

A block argument can specify sub-arguments enclosed in parentheses:

```crystal
array = [{1, "one"}, {2, "two"}]
array.each do |(number, word)|
  puts "#{number}: #{word}"
end
```

The above is simply syntax sugar of this:

```crystal
array = [{1, "one"}, {2, "two"}]
array.each do |arg|
  number = arg[0]
  word = arg[1]
  puts "#{number}: #{word}"
end
```

That means that any type that responds to `[]` with integers can be unpacked in a block argument.

## Performance

When using blocks with `yield`, the blocks are **always** inlined: no closures, calls or function pointers are involved. This means that this:

```crystal
def twice
  yield 1
  yield 2
end

twice do |i|
  puts "Got: #{i}"
end
```

is exactly the same as writing this:

```crystal
i = 1
puts "Got: #{i}"
i = 2
puts "Got: #{i}"
```

For example, the standard library includes a `times` method on integers, allowing you to write:

```crystal
3.times do |i|
  puts i
end
```

This looks very fancy, but is it as fast as a C for loop? The answer is: yes!

This is `Int#times` definition:

```crystal
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

```crystal
i = 0
while i < 3
  puts i
  i += 1
end
```

Have no fear using blocks for readability or code reuse, it won't affect the resulting executable performance.
