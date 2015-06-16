# if

An `if` evaluates the `then` branch if its condition is *truthy*, and evaluates the `else` branch, if there’s any, otherwise.

```ruby
a = 1
if a > 0
  a = 10
end
a #=> 10

b = 1
if b > 2
  b = 10
else
  b = 20
end
b #=> 20
```

To write a chain of if-else-if you use `elsif`:

```ruby
if some_condition
  do_something
elsif some_other_condition
  do_something_else
else
  do_that
end
```

After an `if`, a variable’s type depends on the type of the expressions used in both branches.

```ruby
a = 1
if some_condition
  a = "hello"
else
  a = true
end
# a :: String | Bool

b = 1
if some_condition
  b = "hello"
end
# b :: Int32 | String

if some_condition
  c = 1
else
  c = "hello"
end
# c :: Int32 | String

if some_condition
  d = 1
end
# d :: Int32 | Nil
```

Note that if a variable is declared inside one of the branches but not in the other one, at the end of the `if` it will also contain the `Nil` type.

Inside an `if`'s branch the type of a variable is the one it got assigned in that branch, or the one that it had before the branch if it was not reassigned:

```ruby
a = 1
if some_condition
  a = "hello"
  # a :: String
  a.length
end
# a :: String | Int32
```

That is, a variable’s type is the type of the last expression(s) assigned to it.

If one of the branches never reaches past the end of an `if`, like in the case of a `return`, `next`, `break` or `raise`, that type is not considered at the end of the `if`:

```ruby
if some_condition
  e = 1
else
  e = "hello"
  # e :: String
  return
end
# e :: Int32
```
