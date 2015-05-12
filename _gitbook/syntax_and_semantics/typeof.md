# typeof

The `typeof` expression returns the type of an expression:

```ruby
a = 1
b = typeof(a) #=> Int32
```

It accepts multiple arguments, and the result is the union of the expression types:

```ruby
typeof(1, "a", 'a') #=> (Int32 | String | Char)
```

It is often used in generic code, to make use of the compiler's type inference capabilities:

```ruby
hash = {} of Int32 => String
another_hash = typeof(hash).new #:: Hash(Int32, String)
```

This expression is also available in the [type grammar](type_grammar.html).
