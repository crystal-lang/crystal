# next

You can use `next` to try to execute the next iteration of a `while` loop. After executing `next`, the `while`'s condition is checked and, if *truthy*, the body will be executed.

```ruby
a = 1
while a < 5
  a += 1
  if a == 3
    next
  end
  puts a
end
# The above prints the numbers 2, 4 and 5
```
