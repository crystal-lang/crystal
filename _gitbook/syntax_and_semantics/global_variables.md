# Global variables

Global variables start with a dollar sign (`$`). They are declared when you first assign them a value.

```crystal
$year = 2014
```

Their type is inferred using the [global type inference algorithm](type_inference.html)

Additionally, if your program reads a global variable before it was ever assigned a value it will also have the `Nil` type.
