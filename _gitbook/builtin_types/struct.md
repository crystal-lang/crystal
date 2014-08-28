# Struct

`Struct` is the base class of structs you create in your program. It is set as a struct' superstruct when you don't specify one:

```ruby
struct Foo # < Struct
end
```

Because structs are allocated on the stack and copied around they don't have a heap memory address so they don't have an `object_id` method.
