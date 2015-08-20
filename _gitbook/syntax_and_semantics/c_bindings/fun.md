# fun

A `fun` declaration inside a `lib` binds to a C function.

```ruby
lib C
  # In C: double cos(double x)
  fun cos(value : Float64) : Float64
end
```

Once you bind it, the function is available inside the `C` type as if it was a class method:

```ruby
C.cos(1.5) #=> 0.0707372
```

You can omit the parentheses if the function doesn't have arguments (and omit them in the call as well):

```ruby
lib C
  fun getch : Int32
end

C.getch
```

If the return type is void you can omit it:

```ruby
lib C
  fun srand(seed : UInt32)
end

C.srand(1_u32)
```

You can bind to variadic functions:

```ruby
lib X
  fun variadic(value : Int32, ...) : Int32
end

X.variadic(1, 2, 3, 4)
```

Note that there are no implicit conversions (except `to_unsafe`, explained later) when invoking a C function: you must pass the exact type that is expected. For integers and floats you can use the various `to_...` methods.

Because method names in Crystal must start with a lowercase letter, `fun` names must also start with a lowercase letter. If you need to bind to a C function that starts with a capital letter you can give the function another name for Crystal:

```ruby
lib LibSDL
  fun init = SDL_Init(flags : UInt32) : Int32
end
```

You can also use a string as a name if the name is not a valid identifier or type name:

```ruby
lib LLVMIntrinsics
  fun ceil_f32 = "llvm.ceil.f32"(value : Float32) : Float32
end
```

This can also be used to give shorter, nicer names to C functions, as these tend to be long and usually be prefixed with the library name.

The valid types to use in C bindings are:
* Primitive types (`Int8`, ..., `Int64`, `UInt8`, ..., `UInt64`, `Float32`, `Float64`)
* Pointer types (`Pointer(Int32)`, which can also be written as `Int32*`)
* Static arrays (`StaticArray(Int32, 8)`, which can also be written as `Int32[8]`)
* Function types (`Function(Int32, Int32)`, which can also be written as `Int32 -> Int32`)
* Other `struct`, `union`, `enum`, `type` or `alias` declared previously.
* `Void`: the absence of a return value.
* `NoReturn`: similar to `Void`, but the compiler understands that no code can be executed after that invocation.

Refer to the [type gammar](type_grammar.html) for the notation used in fun types.

The standard library defines the [LibC](https://github.com/manastech/crystal/blob/master/src/libc.cr) lib with aliases for common C types, like `int`, `short`, `size_t`. Use them in bindings like this:

```ruby
lib MyLib
  fun my_fun(some_size : LibC::SizeT)
end
```

**Note:** The C `char` type is `UInt8` in Crystal, so a `char*` or a `const char*` is `UInt8*`. The `Char` type in Crystal is a unicode codepoint so it is represented by four bytes, making it similar to an `Int32`, not to an `UInt8`. There's also the alias `LibC::Char` if in doubt.
