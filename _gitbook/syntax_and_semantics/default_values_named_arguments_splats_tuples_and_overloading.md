# Method arguments

This is the formal specification of method and call arguments.

## Components a method definition

A method definition consist of:

* required and optional positional arguments
* an optional splat argument, whose name can be empty
* required and optional named arguments
* an optional double splat argument

For example:

```crystal
def foo(
  # These are positional arguments:
  x, y, z = 1,
  # This is the splat argument:
  *args,
  # These are the named arguments:
  a, b, c = 2,
  # This is the double splat argument:
  **options
  )
end
```

Each one of them is optional, so a method can do without the double splat, without the splat, without keyword arguments and without positional arguments.

## Components of a method call

A method call also has some parts:

```crystal
foo(
  # These are positional arguments
  1, 2,
  # These are named arguments
  a: 1, b: 2
)
```

Additionally, a call argument can have a splat (`*`) or double splat (`**`). A splat expands a [literals/tuple.html](Tuple) into positional arguments, while a double splat expands a [literals/named_tuple.html](NamedTuple) into named arguments. Multiple argument splats and double splats are allowed.

## How call arguments are matched to method arguments

When invoking a method, the algorithm to match call arguments to method arguments is:

* First positional arguments are matched with positional method arguments. The number of these must be at least the number of positional arguments without a default value. If there's a splat method argument with a name (the case without a name is explained below), more positional arguments are allowed and they are captured as a tuple. Positional arguments never match past the splat method argument.
* Then named arguments are matched, by name, with any argument in the method (it can be before or after the splat method argument). If an argument was already filled by a positional argument then it's an error.
* Extra named arguments are placed in the double splat method argument, as a [literals/named_tuple.html](NamedTuple), if it exists, otherwise it's an error.

When a splat method argument has no name, it means no more positional arguments can be passed, and next arguments must be passed as named arguments. For example:

```crystal
# Only one positional argument allowed, y must be passed as a named argument
def foo(x, *, y)
end

foo 1 # Error, missing argument: y
foo 1, 2 # Error: wrong number of arguments (given 2, expected 1)
foo 1, y: 10 # OK
```

But even if a splat method argument has a name, arguments that follow it must be passed as named arguments:

```crystal
# One or more positional argument allowed, y must be passed as a named argument
def foo(x, *args, y)
end

foo 1 # Error, missing argument: y
foo 1, 2 # Error: missing argument; y
foo 1, 2, 3 # Error: missing argument: y
foo 1, y: 10 # OK
foo 1, 2, 3, y: 4 # OK
```

There's also the possibility of making a method only receive named arguments (and list them), by placing the star at the beginning:

```crystal
# A method with two required named arguments: x and y
def foo(*, x, y)
end

foo # Error: missing arguments: x, y
foo x: 1 # Error: missing argument: y
foo x: 1, y: 2 # OK
```

Arguments past the star can also have default values. It means: they must be passed as named arguments, but they aren't required (so: optional named arguments):

```crystal
# A method with two required named arguments: x and y
def foo(*, x, y = 2)
end

foo # Error: missing argument: x
foo x: 1 # OK, y is 2
foo x: 1, y: 3 # OK, y is 3
```

Because arguments (without a default value) after the splat method argument must be passed by name, two methods with different required named arguments overload:

```crystal
def foo(*, x)
  puts "Passed with x: #{x}"
end

def foo(*, y)
  puts "Passed with y: #{y}"
end

foo x: 1 # => Passed with x: 1
foo y: 2 # => Passed with y: 2
```

Positional arguments can always be matched by name:

```crystal
def foo(x, *, y)
end

foo 1, y: 2 # OK
foo y: 2, x: 3 # OK
```

## External names

An external name can be specified for a method argument. The external name is the one used when passing an argument as a named argument, and the internal name is the one used inside the method definition:

```crystal
def foo(external_name internal_name)
  # here we use internal_name
end

foo external_name: 1
```

This covers two uses cases.

The first use case is using keywords as named arguments:

```crystal
def plan(begin begin_time, end end_time)
  puts "Planning between #{begin_time} and #{end_time}"
end

plan begin: Time.now, end: 2.days.from_now
```

The second use case is making a method argument more readable inside a method body:

```crystal
def increment(value, by)
  # OK, but reads odd
  value + by
end

def increment(value, by amount)
  # Better
  value + amount
end
```

