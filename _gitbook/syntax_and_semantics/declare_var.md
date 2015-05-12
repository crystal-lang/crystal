# Uninitialized variable declaration

Crystal allows declaring uninitialized variables:

```ruby
x :: Int32
x #=> some random value, garbage, unreliable
```

This is [unsafe](unsafe.html) code and is almost always used in low-level code for declaring uninitialized [StaticArray](http://crystal-lang.org/api/StaticArray.html) buffers without a peformance penalty:

```ruby
buffer :: UInt8[256]
```

The buffer is allocated on the stack, avoiding a heap allocation.

The type after the two colons (`::`) follows the [type grammar](type_grammar.html).

