# if var.is_a?(...)

If an `if`'s condition is an `is_a?` test, the type of a variable is guaranteed to be restricted by that type in the `then` branch.

```ruby
if a.is_a?(String)
  # here a is a String
end

if b.is_a?(Number)
  # here b is a Number
end
```

Additionally, in the `else` branch the type of the variable is guaranteed to not be restricted by that type:

```ruby
a = some_condition ? 1 : "hello"
# a :: Int32 | String

if a.is_a?(Number)
  # a :: Int32
else
  # a :: String
end
```

Note that you can use any type as an `is_a?` test, like abstract classes and modules.

The above also works if there are ands (`&&`) in the condition:

```ruby
if a.is_a?(String) && b.is_a?(Number)
  # here a is a String and b is a Number
end
```

The above **doesn’t** work with instance variables, class variables or global variables. To work with these, first assign them to a variable:

```ruby
if @a.is_a?(String)
  # here @a is not guaranteed to be a String
end

a = @a
if a.is_a?(String)
  # here a is guaranteed to be a String
end

# A bit shorter:
if (a = @a).is_a?(String)
  # here a is guaranteed to be a String
end
```
