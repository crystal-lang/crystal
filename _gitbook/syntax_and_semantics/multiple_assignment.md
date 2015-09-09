# Multiple assignment

You can declare/assign multiple variables at the same time by separating expressions with a comma (`,`):

```crystal
name, age = "Crystal", 1

# The above is the same as this:
temp1 = "Crystal"
temp2 = 1
name  = temp1
age   = temp2
```

Note that because expressions are assigned to temporary variables it is possible to exchange variables’ contents in a single line:

```crystal
a = 1
b = 2
a, b = b, a
a #=> 2
b #=> 1
```

If the right-hand side contains just one expression, it is considered an indexed type and the following syntax sugar applies:

```crystal
name, age, source = "Crystal,1,github".split(",")

# The above is the same as this:
temp = "Crystal,1,github".split(",")
name   = temp[0]
age    = temp[1]
source = temp[2]
```

If the left-hand side contains just one variable, the right-hand side is considered an array:

```crystal
names = "John", "Peter", "Jack"

# The above is the same as:
names = ["John", "Peter", "Jack"]
```

Multiple assignment is also available to methods that end with `=`:

```crystal
person.name, person.age = "John", 32

# Same as:
temp1 = "John"
temp2 = 32
person.name = temp1
person.age = temp2
```

And it is also available to indexers (`[]=`):

```crystal
objects[1], objects[2] = 3, 4

# Same as:
temp1 = 3
temp2 = 4
objects[1] = temp1
objects[2] = temp2
```
