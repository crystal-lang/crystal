# Array

An [Array](http://crystal-lang.org/api/Array.html) is a generic type containing elements of a type `T`. It is typically created with an array literal:

```ruby
[1, 2, 3]         # Array(Int32)
[1, "hello", 'x'] # Array(Int32 | String | Char)
```

An Array can have mixed types, meaning `T` will be a union of types, but these are determined when the array is created, either by specifying T or by using an array literal. In the latter case, T will be set to the union of the array literal elements.

When creating an empty array you must always specify T:

```ruby
[] of Int32 # same as Array(Int32).new
[]          # syntax error
```

## Array of String

Arrays of strings can be created with a special syntax:

```ruby
%w(one two three) # ["one", "two", "three"]
```

## Array of Symbol

Arrays of symbols can be created with a special syntax:

```ruby
%i(one two three) # [:one, :two, :three]
```

## Array-like types

You can use a special array literal syntax with other types too, as long as they define an argless `new` method and a `<<` method:

```ruby
MyType{1, 2, 3}
```

If `MyType` is not generic, the above is equivalent to this:

```ruby
tmp = MyType.new
tmp << 1
tmp << 2
tmp << 3
tmp
```

If `MyType` is generic, the above is equivalent to this:

```ruby
tmp = MyType(typeof(1, 2, 3)).new
tmp << 1
tmp << 2
tmp << 3
tmp
```

In the case of a generic type, the type arguments can be specified too:

```ruby
MyType(Int32 | String) {1, 2, "foo"}
```
