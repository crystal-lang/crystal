# Exception handling

Crystal's way to do error handling is by raising and rescuing exceptions.

## Raising exception

You raise exceptions by invoking a top-level `raise` method. Unlike other keywords, `raise` is a regular method with two overloads: [one accepting a String](http://crystal-lang.org/api/toplevel.html#raise%28message%20%3A%20String%29-class-method) and another [accepting an Exception instance](http://crystal-lang.org/api/toplevel.html#raise%28ex%20%3A%20Exception%29-class-method):

```ruby
raise "OH NO!"
raise Exception.new("Some error")
```

The String version just creates a new [Exception](http://crystal-lang.org/api/Exception.html) instance with that message.

Only `Exception` instances or subclasses can be raised.

## Defining custom exceptions

To define a custom exception type, just subclass from [Exception](http://crystal-lang.org/api/Exception.html):

```ruby
class MyException < Exception
end

class MyOtherException < Exception
end
```

You can, as always, define a constructor for your exception or just use the default one.

## Rescuing exceptions

To rescue any exception use a `begin ... rescue ... end` expression:

```ruby
begin
  raise "OH NO!"
rescue
  puts "Rescued!"
end

# Output: Rescued!
```

To access the rescued exception you can specify a variable in the `rescue` clause:

```ruby
begin
  raise "OH NO!"
rescue ex
  puts ex.message
end

# Output: OH NO!
```

To rescue just one type of exception (or any of its subclasses):

```ruby
begin
  raise MyException.new("OH NO!")
rescue MyException
  puts "Rescued MyException"
end

# Output: Rescued MyException
```

And to access it, use a syntax similar to type restrictions:

```ruby
begin
  raise MyException.new("OH NO!")
rescue ex : MyException
  puts "Rescued MyException: #{ex.message}"
end

# Output: Rescued MyException: OH NO!
```

Multiple `rescue` clauses can be specified:

```ruby
begin
  # ...
rescue ex1 : MyException
  # only MyException...
rescue ex2 : MyOtherException
  # only MyOtherException...
rescue
  # any other kind of exception
end
```

You can also rescue multiple exception types at once by specifying a union type:

```ruby
begin
  # ...
rescue ex : MyException | MyOtherException
  # only MyException or MyOtherException
rescue
  # any other kind of exception
end
```

## ensure

An `ensure` clause is executed at the end of a `begin ... end` or `begin ... rescue ... end` expression regardless of whether an exception was raised or not:

```ruby
begin
  something_dangerous
ensure
  puts "Cleanup..."
end

# Will print "Cleanup..." after invoking something_dangerous,
# regardless of whether it raised or not
```

Or:

```ruby
begin
  something_dangerous
rescue
  # ...
ensure
  # this will always be executed
end
```

`ensure` clauses are usually used for clean up, freeing resources, etc.

## else

An `else` clause is executed only if no exceptions were rescued:

```ruby
begin
  something_dangerous
rescue
  # execute this if an exception is raised
else
  # execute this if an exception isn't raised
end
```

An `else` clause can only be specified if at least one `rescue` clause is specified.

## Short syntax form

Exception handling has a short syntax form: assume a method definition is an implicit `begin ... end` expression, then specify `rescue`, `ensure` and `else` clauses:

```ruby
def some_method
  something_dangerous
rescue
  # execute if an exception is raised
end

# The above is the same as:
def some_method
  begin
    something_dangerous
  rescue
    # execute if an exception is raised
  end
end
```

An example with `ensure`:

```ruby
def some_method
  something_dangerous
ensure
  # always execute this
end

# The above is the same as:
def some_method
  begin
    something_dangerous
  ensure
    # always execute this
  end
end
```

## Type inference

Variables declared inside the `begin` part of an exception handler also get the `Nil` type when considered inside a `rescue` or `ensure` body. For example:

```ruby
begin
  a = something_dangerous_that_returns_Int32
ensure
  puts a + 1 # error, undefined method '+' for Nil
end
```

The above happens even if `something_dangerous_that_returns_Int32` never raises, or if `a` was assigned a value and then a method that potentially raises is executed:

```ruby
begin
  a = 1
  something_dangerous
ensure
  puts a + 1 # error, undefined method '+' for Nil
end
```

Although it is obvious that `a` will always be assigned a value, the compiler will still think `a` might never had a chance to be initialized. Even though this logic might improve in the future, right now it forces you to keep your exception handlers to their necessary minimum, making the code's intention more clear:

```ruby
# Clearer than the above: `a` doesn't need
# to be in the exception handling code.
a = 1
begin
  something_dangerous
ensure
  puts a + 1 # works
end
```

## Alternative ways to do error handling

Although exceptions are available as one of the mechanisms for handling errors, they are not your only choice. Raising an exception involves allocating memory, and executing an exception handler is generally slow.

The standard library usually provides a couple of methods to accomplish something: one raises, one returns `nil`. For example:

```ruby
array = [1, 2, 3]
array[4]  # raises because of IndexOutOfBounds
array[4]? # returns nil because of index out of bounds
```

The usual convention is to provide an alternative "question" method to signal that this variant of the method returns `nil` instead of raising. This lets the user choose whether she wants to deal with exceptions or with `nil`. Note, however, that this is not avaialble for every method out there, as exceptions are still the preferred way because they don't pollute the code with error handling logic.
