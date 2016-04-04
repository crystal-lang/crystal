# if !

The `!` operator returns a `Bool` that results from negating the [truthyness](truthy_and_falsey_values.html) of a value.

When used in an `if` in conjuntion with a variable, `is_a?`, `responds_to?` or `nil?` the compiler will restrict the types accordingly:

```crystal
a = some_condition ? nil : 3
if !a
  # here a is Nil because a is falsey in this branch
else
  # here a is Int32, because a is truthy in this branch
end
```

```crystal
b = some_condition ? 1 : "x"
if !b.is_a?(Int32)
  # here b is String because it's not an Int32
end
```
