# As an expression

The value of an `if` is the value of the last expression found in each of its branches:

```ruby
a = if 2 > 1
      3
    else
      4
    end
a #=> 3
```

If an `if` branch is empty, or it’s missing, it’s considered as if it had `nil` in it:

```ruby
if 1 > 2
  3
end

# The above is the same as:
if 1 > 2
  3
else
  nil
end

# Another example:
if 1 > 2
else
  3
end

# The above is the same as:
if 1 > 2
  nil
else
  3
end
```
