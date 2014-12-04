# callbacks

You can use function types in C declarations:

```ruby
lib X
  # In C:
  #
  #    void callback(int (*f)(int));
  fun callback(f : Int32 -> Int32)
end
```

Then you can pass a function like this:

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

If the compiler can't detect this at compile-time, an exception will be thrown at runtime.
