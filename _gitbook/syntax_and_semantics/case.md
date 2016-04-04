# case

A `case` is a control expression that allows a sort of pattern matching. It allows writing a chain of if-else-if with a small change in semantic and some more powerful constructs.

In its basic form, it allows matching a value against other values:

```crystal
case exp
when value1, value2
  do_something
when value3
  do_something_else
else
  do_another_thing
end

# The above is the same as:
tmp = exp
if value1 === tmp || value2 === tmp
  do_something
elsif value3 === tmp
  do_something_else
else
  do_another_thing
end
```

Note that `===` is used for comparing an expression against a `case`'s value.

If a `when`'s expression is a type, `is_a?` is used. Additionally, if the case expression is a variable or a variable assignment the type of the variable is restricted:

```crystal
case var
when String
  # var : String
  do_something
when Int32
  # var : Int32
  do_something_else
else
  # here var is neither a String nor an Int32
  do_another_thing
end

# The above is the same as:
if var.is_a?(String)
  do_something
elsif var.is_a?(Int32)
  do_something_else
else
  do_another_thing
end
```

You can invoke a method on the `case`'s expression in a `when` by using the implicit-object syntax:

```crystal
case num
when .even?
  do_something
when .odd?
  do_something_else
end

# The above is the same as:
tmp = num
if tmp.even?
  do_something
elsif tmp.odd?
  do_something_else
end
```

Finally, you can ommit the `case`'s value:

```crystal
case
when cond1, cond2
  do_something
when cond3
  do_something_else
end

# The above is the same as:
if cond1 || cond2
  do_something
elsif cond3
  do_something_else
end
```

This sometimes leads to code that is more natural to read.

## Tuple literal

When a case expression is a tuple literal there are a few semantic differences if a when condition is also a tuple literal.

### Tuple size must match

```crystal
case {value1, value2}
when {0, 0} # OK, 2 elements
  # ...
when {1, 2, 3} # Compiler error, because it will never match
  # ...
end
```

### Underscore allowed

```crystal
case {value1, value2}
when {0, _}
  # Matches if 0 === value1, no test done against value2
when {_, 0}
  # Matches if 0 === value2, no test done against value1
end
```

### Implicit-object allowed

```crystal
case {value1, value2}
when {.even?, .odd?}
  # Matches if value1.even? && value2.odd?
end
```

### Comparing against a type will perform an is_a? check

```crystal
case {value1, value2}
when {String, Int32}
  # Matches if value1.is_a?(String) && value2.is_a?(Int32)
  # The type of value1 is known to be a String by the compiler,
  # and the type of value2 is known to be an Int32
end
```
