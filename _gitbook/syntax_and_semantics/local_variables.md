# Local variables

Local variables start with lowercase letters. They are declared when you first assign them a value.

```ruby
name = "Crystal"
age = 1
```

Their type is inferred from their usage, not only from their initializer. In general, they are just value holders associated with the type that the programmer expects them to have according to their location and usage on the program.

For example, reassigning a variable with a different expression makes it have that expression’s type:

```ruby
var = "Hello"
# At this point 'var' is a String

var = 1
# At this point 'var' is an Int32
```

Underscores are allowed at the beginning of a variable name, but these names are reserved for the compiler, so their use is not recommended (and it also makes the code uglier to read).
