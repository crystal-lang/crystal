# Hash

A [Hash](http://crystal-lang.org/api/Hash.html) representing a mapping of keys of a type `K` to values of a type `V`. It is typically created with a hash literal:

```ruby
{1 => 2, 3 => 4}     # Hash(Int32, Int32)
{1 => 2, 'a' => 3}   # Hash(Int32 | Char, Int32)
```

A Hash can have mixed types, both for the keys and values, meaning `K`/`V` will be union types, but these are determined when the hash is created, either by specifying `K` and `V` or by using a hash literal. In the latter case, `K` will be set to the union of the hash literal keys, and `V` will be set to the union of the hash literal values.

When creating an empty hash you must always specify `K` and `V`:

```ruby
{} of Int32 => Int32 # same as Hash(Int32, Int32).new
{}                   # syntax error
```

## Symbol keys

A special notation allows creating hashes with symbol keys:

```ruby
{key1: 'a', key2: 'b'} # Hash(Symbol, Char)
```

## String keys

A special notation allows creating hashes with string keys:

```ruby
{"key1": 'a', "key2": 'b'} # Hash(String, Char)
```

## Hash-like types

You can use a special hash literal syntax with other types too, as long as they define an argless `new` method and a `[]=` method:

```ruby
MyType{"foo": "bar"}
```

If `MyType` is not generic, the above is equivalent to this:

```ruby
tmp = MyType.new
tmp["foo"] = "bar"
tmp
```

If `MyType` is generic, the above is equivalent to this:

```ruby
tmp = MyType(typeof("foo"), typeof("bar")).new
tmp["foo"] = "bar"
tmp
```

In the case of a generic type, the type arguments can be specified too:

```ruby
MyType(String, String) {"foo": "bar"}
```
