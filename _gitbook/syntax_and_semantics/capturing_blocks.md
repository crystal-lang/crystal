# Capturing blocks

A block can be captured and turned into a `Proc`, which represents a block of code with an associated context: the closured data.

To capture a block you must specify it as a method's block argument, give it a name and specify the input and output types. For example:

```ruby
def int_to_int(&block : Int32 -> Int32)
  block
end

proc = int_to_int { |x| x + 1 }
proc.call(1) #=> 2
```

The above code captures the block of code passed to `int_to_int` in the `block` variable, and returns it from the method. The type of `proc` is [Proc(Int32, Int32)](http://crystal-lang.org/api/Proc.html), a function that accepts a single `Int32` argument and returns an `Int32`.

In this way a block can be saved as a callback:

```ruby
class Model
  def on_save(&block)
    @on_save_callback = block
  end

  def save
    if callback = @on_save_callback
      callback.call
    end
  end
end

model = Model.new
model.on_save { puts "Saved!" }
model.save # prints "Saved!"
```

In the above example the type of `&block` wasn't specified: this just means that the captured block doesn't have arguments and doesn't return anything.

Note that if the return type is not specified, nothing gets returned from the proc call:

```ruby
def some_proc(&block : Int32 ->)
  block
end

proc = some_proc { |x| x + 1 }
proc.call(1) # void
```

To have something returned, either specify the return type or use an underscore to allow any return type:

```ruby
def some_proc(&block : Int32 -> _)
  block
end

proc = some_proc { |x| x + 1 }
proc.call(1) # 2

proc = some_proc { |x| x.to_s }
proc.call(1) # "1"
```

## break and next

`break` and `next` can't be used inside a captured block. `return` can be used and will exit from the block (not the surrounding method).

The semantic for `next` and `return` inside captured blocks [might swap in the future](https://github.com/manastech/crystal/issues/420).

## with ... yield

The default receiver within a captured block can't be changed by using `with ... yield`.
