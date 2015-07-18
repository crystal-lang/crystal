# if var

If a variable is the condition of an `if`, inside the `then` branch the variable will be considered as not having the `Nil` type:

```ruby
a = some_condition ? nil : 3
# a is Int32 or Nil

if a
  # Since the only way to get here is if a is truthy,
  # a can't be nil. So here a is Int32.
  a.abs
end
```

This also applies when a variable is assigned in an `if`'s condition:

```ruby
if a = some_expression
  # here a is not nil
end
```

This logic also applies if there are ands (`&&`) in the condition:

```ruby
if a && b
  # here both a and b are guaranteed not to be Nil
end
```

Here, the right-hand side of the `&&` expression is also guaranteed to have `a` as not `Nil`.

Of course, reassigning a variable inside the `then` branch makes that variable have a new type based on the expression assigned.

The above logic **doesn’t** work with instance variables, class variables or global variables:

```ruby
if @a
  # here @a can be nil
end
```

This is because any method call could potentially affect that instance variable, rendering it `nil`. Another reason is that another thread could change that instance variable after checking the condition.

To do something with `@a` only when it is not `nil` you have two options:

```ruby
# First option: assign it to a variable
if a = @a
  # here a can't be nil
end

# Second option: use `Object#try` found in the standard library
@a.try do |a|
  # here a can't be nil
end
```

That logic also doesn't work with proc and method calls, including getters and properties, because nilable (or, more generally, union-typed) procs and methods aren't guaranteed to return the same more-specific type on two successive calls.

```ruby
if method # first call to a method that can return Int32 or Nil
          # here we know that the first call did not return Nil
  method  # second call can still return Int32 or Nil
end
```

The techniques described above for instance variables will also work for proc and method calls.
