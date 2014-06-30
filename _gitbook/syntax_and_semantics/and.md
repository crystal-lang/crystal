# &&

An `&&` (and) evaluates its left hand side. If its *truthy*, it evaluates its right hand side and has that value. Otherwise it has the value of the left hand side. Its type it the union of the types of both sides.

You can think an `&&` as syntax sugar of an `if`:

``` ruby
some_exp1 && some_exp2

# The above is the same as:
tmp = some_exp1
if tmp
  some_exp2
else
  tmp
end
```
