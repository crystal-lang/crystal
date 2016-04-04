# if var.nil?

If an `if`'s condition is `var.nil?` then the type of `var` in the `then` branch is known by the compiler to be `Nil`, and to be known as non-`Nil` in the `else` branch:

```crystal
a = some_condition ? nil : 3
if a.nil?
  # here a is Nil
else
  # here a is Int32
end
```
