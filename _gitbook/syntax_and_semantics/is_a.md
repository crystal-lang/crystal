# is_a?

The pseudo-method `is_a?` determines whether an expression's runtime type inherits or includes another type. For example:

```crystal
a = 1
a.is_a?(Int32)          #=> true
a.is_a?(String)         #=> false
a.is_a?(Number)         #=> true
a.is_a?(Int32 | String) #=> true
```

It is a pseudo-method because the compiler knows about it and it can affect type information, as explained in [if var.is_a?(...)](if_varis_a.html). Also, it accepts a [type](type_grammar.html) that must be known at compile-time as its argument.
