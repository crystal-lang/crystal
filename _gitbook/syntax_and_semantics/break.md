# break

You can use `break` to break out of a `while` loop:

```crystal
a = 2
while (a += 1) < 20
  if a == 10
    # goes to 'puts a'
    break
  end
end
puts a #=> 10
```
