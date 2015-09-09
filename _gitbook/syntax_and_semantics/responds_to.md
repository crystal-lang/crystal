# responds_to?

The pseudo-method `responds_to?` determines whether a type has a method with the given name. For example:

```crystal
a = 1
a.responds_to?(:abs)    #=> true
a.responds_to?(:size) #=> false
```

It is a pseudo-method because it only accepts a symbol literal as its argument, and is also treated specially by the compiler, as explained in [if var.responds_to?(...)](if_varresponds_to.html).
