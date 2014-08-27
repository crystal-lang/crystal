# fun

A `fun` declaration inside a `lib` binds to a C function.

```ruby
lib C
  fun cos(value : Float64) : Float64
end
```

Once you bind it, the function is available inside the `C` type as if it was a class method:

```ruby
C.cos(1.5) #=> 0.0707372
```

You can ommit the parenthesis if the function doesn't have arguments (and ommit them in the call as well):

```ruby
lib C
  fun getch : Int32
end

C.getch
```

If the return type is void you can ommit it:

```ruby
lib C
  fun srand(seed : UInt32)
end

C.srand(1_u32)
```

Note that there are no implicit conversions (except `to_unsafe`, explained later) when invoking a C function: you must pass the exact type that is expected. For integers and floats you can use the various `to_...` methods.

Because method names in Crystal must start with a lowercase letter, `fun` names must also start with a lowercase letter. If you need to bind to a C function that starts with a capital letter you can give the function another name for Crystal:

```ruby
lib LibSDL("SDL")
  fun init = SDL_Init(flags : UInt32) : Int32
end
```

You can also use a string as a name if the name is not a valid identifier or type name:

```ruby
lib LLVMIntrinsics
  fun ceil_f32 = "llvm.ceil.f32"(value : Float32) : Float32
end
```

This can also be used to give shorter, nicer names to C functions, as these tend to be long and usually be prefixed with the library name, but in Crystal you must always prefix them with the `lib` name, so it's the same.

The valid types to use in C bindings are:
* Primitive types (`Int8`, ..., `Int64`, `UInt8`, ..., `UInt64`, `Float32`, `Float64`)
* Pointer types (`Pointer(Int32)`, which can also be written as `Int32*`)
* Static arrays (`StaticArray(Int32, 8)`, which can also be written as `Int32[8]`)
* Other `struct`, `union`, `enum`, `type` or `alias` declared previously.

**Note:** The C `char` type is `UInt8` in Crystal, so a `char*` or a `const char*` is `UInt8*`.
