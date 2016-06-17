# Callbacks

You can use function types in C declarations:

```crystal
lib X
  # In C:
  #
  #    void callback(int (*f)(int));
  fun callback(f : Int32 -> Int32)
end
```

Then you can pass a function (a [Proc](http://crystal-lang.org/api/Proc.html)) like this:

```crystal
f = ->(x : Int32) { x + 1 }
X.callback(f)
```

If you define the function inline in the same call you can omit the argument types, the compiler will add the types for you based on the `fun` signature:

```crystal
X.callback ->(x) { x + 1 }
```

Note, however, that functions passed to C can't form closures. If the compiler detects at compile-time that a closure is being passed, an error will be issued:

```crystal
y = 2
X.callback ->(x) { x + y } # Error: can't send closure
                           # to C function
```

If the compiler can't detect this at compile-time, an exception will be raised at runtime.

Refer to the [type grammar](type_grammar.html) for the notation used in callbacks and procs types.

If you want to pass `NULL` instead of a callback, just pass `nil`:

```crystal
# Same as callback(NULL) in C
X.callback nil
```

### Passing a closure to a C function

Most of the time a C function that allows setting a callback also provide an argument for custom data. This custom data is then sent as an argument to the callback. For example, suppose a C function that invokes a callback at every tick, passing that tick:

```crystal
lib LibTicker
  fun on_tick(callback : (Int32, Void* ->), data : Void*)
end
```

To properly define a wrapper for this function we must send the Proc as the callback data, and then convert that callback data to the Proc and finally invoke it.

```crystal
module Ticker
  # The callback for the user doesn't have a Void*
  def self.on_tick(&callback : Int32 ->)
    # We must save this in Crystal-land so the GC doesn't collect it (*)
    @@callback = callback

    # Since Proc is a {Void*, Void*}, we can't turn that into a Void*, so we
    # "box" it: we allocate memory and store the Proc there
    boxed_data = Box.box(callback)

    # We pass a callback that doesn't form a closure, and pass the boxed_data as
    # the callback data
    LibTicker.on_tick(->(tick, data) {
      # Now we turn data back into the Proc, using Box.unbox
      data_as_callback = Box(typeof(callback)).unbox(data)
      # And finally invoke the user's callback
      data_as_callback.call(tick)
    }, boxed_data)
  end
end

Ticker.on_tick do |tick|
  puts tick
end
```

Note that we save the callback in `@@callback`. The reason is that if we don't do it, and our code doesn't reference it anymore, the GC will collect it. The C library will of course store the callback, but Crystal's GC has no way of knowing that.

## Raises attribute

If a C function executes a user-provided callback that might raise, it must be annotated with the `@[Raises]` attribute.

The compiler infers this attribute for a method if it invokes a method that is marked as `@[Raises]` or raises (recursively).

However, some C functions accept callbacks to be executed by other C functions. For example, suppose a fictitious library:

```crystal
lib LibFoo
  fun store_callback(callback : ->)
  fun execute_callback
end

LibFoo.store_callback ->{ raise "OH NO!" }
LibFoo.execute_callback
```

If the callback passed to `store_callback` raises, then `execute_callback` will raise. However, the compiler doesn't know that `execute_callback` can potentially raise because it is not marked as `@[Raises]` and the compiler has no way to figure this out. In these cases you have to manually mark such functions:

```crystal
lib LibFoo
  fun store_callback(callback : ->)

  @[Raises]
  fun execute_callback
end
```

If you don't mark them, `begin/rescue` blocks that surround this function's calls won't work as expected.
