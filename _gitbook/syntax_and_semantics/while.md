# while

A `while` executes its body as long as its condition is *truthy*.

```crystal
while some_condition
  do_this
end
```

The condition is first tested and, if *truthy*, the body is executed. That is, the body might never be executed.

A `while`'s type is always `Nil`.

Similar to an `if`, if a `while`'s condition is a variable, the variable is guaranteed to not be `nil` inside the body. If the condition is an `var.is_a?(Type)` test, `var` is guaranteed to be of type Type inside the body. And if the condition is a `var.responds_to?(:method)`, `var` is guaranteed to be of a type that responds to that method.

The type of a variable after a `while` depends on the type it had before the `while` and the type it had before leaving the `while`'s body:

```crystal
a = 1
while some_condition
  # a : Int32 | String
  a = "hello"
  # a : String
  a.size
end
# a : Int32 | String
```

## Checking the condition at the end of a loop

If you need to execute the body at least once and then check for a breaking condition, you can do this:

```crystal
while true
  do_something
  break if some_condition
end
```

Or use `loop`, found in the standard library:

```crystal
loop do
  do_something
  break if some_condition
end
```
