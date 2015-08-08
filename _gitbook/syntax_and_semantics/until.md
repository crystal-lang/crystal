# until

An `until` executes its body until its condition is *truthy*. An `until` is just syntax sugar for a `while` with the condition negated:

```ruby
until some_condition
  do_this
end

# The above is the same as:
while !some_condition
  do_this
end
```

`break` and `next` can also be used inside an `until`.
