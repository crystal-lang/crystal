# As a suffix

An `if` can be written as an expression’s suffix:

```crystal
a = 2 if some_condition

# The above is the same as:
if some_condition
  a = 2
end
```

This sometimes leads to code that is more natural to read.
