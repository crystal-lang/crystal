# alias

With `alias` you can give a type a different name:

```crystal
alias PInt32 = Pointer(Int32)

ptr = PInt32.malloc(1) # : Pointer(Int32)
```

Every time you use an alias the compiler replaces it with the type it refers to.

Aliases are useful to avoid writing long type names, but also to be able to talk about recursive types:

```crystal
alias RecArray = Array(Int32) | Array(RecArray)

ary = [] of RecArray
ary.push [1, 2, 3]
ary.push ary
ary #=> [[1, 2, 3], [...]]
```

A real-world example of a recursive type is json:

```crystal
module Json
  alias Type = Nil |
               Bool |
               Int64 |
               Float64 |
               String |
               Array(Type) |
               Hash(String, Type)
end
```
