# nil?

The pseudo-method `nil?` determines whether an expression's runtime is `Nil`. For example:

```crystal
a = 1
a.nil?          # => false

b = nil
b.nil?          # => true
```

It is a pseudo-method because the compiler knows about it and it can affect type information, as explained in [if var.nil?(...)](if_var_nil.html).

It has the same effect as writing `is_a?(Nil)` but it's shorter and easier to read and write.
