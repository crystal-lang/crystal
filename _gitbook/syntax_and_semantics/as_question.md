# as?

The `as?` pseudo-method is similar to `as`, except that it returns `nil` instead of raising an exception when the type doesn't match. It also can't be used to cast between pointer types and other types.

Example:

```crystal
value = rand < 0.5 ? -3 : nil
result = value.as?(Int32) || 10

value.as?(Int32).try &.abs
```
