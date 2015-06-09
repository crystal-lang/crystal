# Callbacks

You can use function types in C declarations:

```ruby
lib X
  # In C:
  #
  #    void callback(int (*f)(int));
  fun callback(f : Int32 -> Int32)
end
```

Then you can pass a function (a [Proc](http://crystal-lang.org/api/Proc.html)) like this:

```ruby
f = ->(x : Int32) { x + 1 }
X.callback(f)
```

If you define the function inline in the same call you can omit the argument types, the compiler will add the types for you based on the `fun` signature:

```ruby
X.callback ->(x) { x + 1 }
```

Note, however, that functions passed to C can't form closures. If the compiler detects at compile-time that a closure is being passed, an error will be issued:

```ruby
y = 2
X.callback ->(x) { x + y } # Error: can't send closure
                           # to C function
```

If the compiler can't detect this at compile-time, an exception will be raised at runtime.

Refer to the [type grammar](type_grammar.html) for the notation used in callbacks and procs types.

## Raises attribute

If a C function executes a user-provided callback that might raise, it must be annotated with the `@[Raises]` attribute.

The compiler infers this attribute for a method if it invokes a method that is marked as `@[Raises]` or raises (recursively).

However, some C functions accept callbacks to be executed by other C functions. For example, suppose a ficticious library:

```ruby
lib LibFoo
  fun store_callback(callback : ->)
  fun execute_callback
end

LibFoo.store_callback ->{ raise "OH NO!" }
LibFoo.execute_callback
```

If the callback passed to `store_callback` raises, then `execute_callback` will raise. However, the compiler doesn't know that `execute_callback` can potentially raise because it is not marked as `@[Raises]` and the compiler has no way to figure this out. In these cases you have to manually mark such functions:

```ruby
lib LibFoo
  fun store_callback(callback : ->)

  @[Raises]
  fun execute_callback
end
```

If you don't mark them, `begin/rescue` blocks that surround this function's calls won't work as expected.
