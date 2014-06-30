# if var

If a variable is the condition of an `if`, inside the `then` branch the variable will be considered as not having the `Nil` type:

``` ruby
a = 1 > 2 ? nil : 3
# a is Int32 or Nil

if a
  # Since the only way to get here is if a is truthy,
  # a can't be nil. So here a is Int32.
  a.abs
end
```

This also applies when a variable is assigned in an `if`'s condition:

``` ruby
if a = some_expression
  # here a is not nil
end
```

This logic also applies if there are ands (`&&`) in the condition:

``` ruby
if a && b
  # here both a and b are guaranteed not to be Nil
end
```

Here, the right-hand side of the `&&` expression is also guaranteed to have `a` as not `Nil`.

Of course, reassigning a variable inside the `then` branch makes that variable have a new type based on the expression assigned.

The above logic doesn’t work with instance variables, class variables or global variables:

``` ruby
if @a
  # here @a can be nil
end
```

This is because any method call could potentially affect that instance variable, rendering it `nil`. Another reason is that another thread could change that instance variable after checking the condition.

To do something with `@a` only when it is not `nil` you have two options:

``` ruby
# First option: assign it to a variable
if a = @a
  # here a can't be nil
end

# Second option: use `Object#try` found in the standard library
@a.try do |a|
  # here a can't be nil
end
```
