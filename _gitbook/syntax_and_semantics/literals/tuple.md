# Tuple

A [Tuple](http://crystal-lang.org/api/Tuple.html) is typically created with a tuple literal:

```crystal
tuple = {1, "hello", 'x'} # Tuple(Int32, String, Char)
tuple[0]                  #=> 1       (Int32)
tuple[1]                  #=> "hello" (String)
tuple[2]                  #=> 'x'     (Char)
```

To create an empty tuple use [Tuple.new](http://crystal-lang.org/api/Tuple.html#new%28%2Aargs%29-class-method).

To denote a tuple type you can write:

```crystal
# The type denoting a tuple of Int32, String and Char
Tuple(Int32, String, Char)
```

In type restrictions, generic type arguments and other places where a type is expected, you can use a shorter syntax, as explained in the [type](type_grammar.html):

```crystal
# An array of tuples of Int32, String and Char
Array({Int32, String, Char})
```
