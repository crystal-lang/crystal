# Hash

A [Hash](http://crystal-lang.org/api/Hash.html) representing a mapping of keys of a type `K` to values of a type `V`. It is typically created with a hash literal:

```crystal
{1 => 2, 3 => 4}     # Hash(Int32, Int32)
{1 => 2, 'a' => 3}   # Hash(Int32 | Char, Int32)
```

A Hash can have mixed types, both for the keys and values, meaning `K`/`V` will be union types, but these are determined when the hash is created, either by specifying `K` and `V` or by using a hash literal. In the latter case, `K` will be set to the union of the hash literal keys, and `V` will be set to the union of the hash literal values.

When creating an empty hash you must always specify `K` and `V`:

```crystal
{} of Int32 => Int32 # same as Hash(Int32, Int32).new
{}                   # syntax error
```

## Symbol / String key shorthand

A special shorthand allows creating hashes with symbol keys:

```crystal
one = {key1: 'a', key2: 'b'} # Hash(Symbol, Char)
two = {:key1 => 'a', :key2 => 'b'} # Hash(Symbol, Char)

one == two #=> true
```

similarly with string keys:

```crystal
one = {"key1": 'a', "key2": 'b'} # Hash(String, Char)
two = {"key1" => 'a', "key2" => 'b'} # Hash(String, Char)
one == two #=> true
```

## Getting / Setting data

A Hash value can be set using [Hash#\[\]=](http://crystal-lang.org/api/Hash.html#%5B%5D%3D%28key%3AK%2Cvalue%3AV%29-instance-method), but only as long as the key and value types match the declaration:

```crystal
one = {"foo": 'f', "bit": 'b'} # Hash(String, Char)

one["zon"] = 'z'
puts one[:aph] = 'a' # Compile error: no overload matches 'Hash(String, Char)#[]=' with types Symbol, Char
```

Hash values can be retrieved using [Hash#\[\]](http://crystal-lang.org/api/Hash.html#%5B%5D%28key%29-instance-method), [Hash#\[\]?](http://crystal-lang.org/api/Hash.html#%5B%5D%3F%28key%29-instance-method), or [Hash#fetch](http://crystal-lang.org/api/Hash.html#fetch%28key%2Cdefault%29-instance-method):

```crystal
one = {"foo": 'f', "bit": 'b'} # Hash(String, Char)

# with []
begin
  one["foo"]  #=> 'f'
  one["baz"]  # raises KeyError for Missing hash key: "bar"
rescue KeyError
  puts "no \"baz\" found"
end

# with []?
one["baz"]?         #=> nil
typeof(one["bar"]?) #=> (Nil | Char)

# with fetch
one.fetch "foo"     #=> 'f'
```

## Hash-like types

You can use a special hash literal syntax with other types too, as long as they define an argless `new` method and a `[]=` method:

```crystal
MyType{"foo": "bar"}
```

If `MyType` is not generic, the above is equivalent to this:

```crystal
tmp = MyType.new
tmp["foo"] = "bar"
tmp
```

If `MyType` is generic, the above is equivalent to this:

```crystal
tmp = MyType(typeof("foo"), typeof("bar")).new
tmp["foo"] = "bar"
tmp
```

In the case of a generic type, the type arguments can be specified too:

```crystal
MyType(String, String) {"foo": "bar"}
```
