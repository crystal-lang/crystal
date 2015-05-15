# Proc literal

A captured block is the same as declaring a [Proc literal](literals/proc.html) and [passing](block_forwarding.html) it to the method.

```ruby
def some_proc(&block : Int32 -> Int32)
  block
end

x = 0
proc = ->(i : Int32) { x += i }
proc = some_proc(&proc)
proc.call(1)  #=> 1
proc.call(10) #=> 11
x #=> 11
```

As explained in the [proc literals](literals/proc.html) section, a Proc can also be created from existing methods:

```ruby
def add(x, y)
  x + y
end

adder = ->add(Int32, Int32)
adder.call(1, 2) #=> 3
```
