# Block forwarding

To forward captured blocks, you use a block argument, prefixing an expression with `&`:

```ruby
def capture(&block)
  block
end

def invoke(&block)
  block.call
end

proc = capture { puts "Hello" }
invoke(&proc) # prints "Hello"
```

In the above example, `invoke` receives a block. We can't pass `proc` directly to it because `invoke` doesn't receive regular arguments, just a block argument. We use `&` to specify that we really want to pass `proc` as the block argument. Otherwise:

```ruby
invoke(proc) # Error: wrong number of arguments for 'invoke' (1 for 0)
```

You can actually pass a proc to a method that yields:

```ruby
def capture(&block)
  block
end

def twice
  yield
  yield
end

proc = capture { puts "Hello" }
twice &proc
```

The above is simpy rewritten to:

```ruby
proc = capture { puts "Hello" }
twice do
  proc.call
end
```

Or, combining the `&` and `->` syntaxes:

```ruby
twice &->{ puts "Hello" }
```

Or:

```ruby
def say_hello
  puts "Hello"
end

twice &->say_hello
```

## Forwarding non-captured blocks

To forward non-captured blocks, you must use `yield`:

```ruby
def foo
  yield 1
end

def wrap_foo
  puts "Before foo"
  foo do |x|
    yield x
  end
  puts "After foo"
end

wrap_foo do |i|
  puts i
end

# Output:
# Before foo
# 1
# After foo
```

You can also use the `&block` syntax to forward blocks, but then you have to at least specify the input types, and the generated code will involve closures and will be slower:

```ruby
def foo
  yield 1
end

def wrap_foo(&block : Int32 -> _)
  puts "Before foo"
  foo(&block)
  puts "After foo"
end

wrap_foo do |i|
  puts i
end

# Output:
# Before foo
# 1
# After foo
```

Try to avoid forwarding blocks like this if doing `yield` is enough. There's also the issue that `break` and `next` are not allowed inside captured blocks, so the following won't work when using `&block` forwarding:

```ruby
foo_forward do |i|
  break # error
end
```

In short, avoid `&block` forwarding when `yield` is involved.
