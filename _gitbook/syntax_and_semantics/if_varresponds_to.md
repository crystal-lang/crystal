# if var.responds_to?(...)

If an `if`'s condition is a `responds_to?` test, in the `then` branch the type of a variable is guaranteed to be restricted to the types that respond to that method:

```ruby
if a.responds_to?(:abs)
  # here a's type will be reduced to those responding to the 'abs' method
end
```

Additionally, in the `else` branch the type of the variable is guaranteed to be restricted to the types that don’t respond to that method:

```ruby
a = some_condition ? 1 : "hello"
# a :: Int32 | String

if a.responds_to?(:abs)
  # here a will be Int32, since Int32#abs exists but String#abs doesn't
else
  # here a will be String
end
```

The above **doesn’t** work with instance variables, class variables or global variables. To work with these, first assign them to a variable:

```ruby
if @a.responds_to?(:abs)
  # here @a is not guaranteed to respond to `abs`
end

a = @a
if a.responds_to?(:abs)
  # here a is guaranteed to respond to `abs`
end

# A bit shorter:
if (a = @a).responds_to?(:abs)
  # here a is guaranteed to respond to `abs`
end
```

