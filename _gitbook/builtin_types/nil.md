# Nil

The `Nil` type has one possible value: `nil`.

`nil` is commonly used to represent the absence of a value. For example, `String#index` returns the position of the character or `nil` if it's not in the string:

```ruby
str = "Hello world"
str.index 'e' #=> 1
str.index 'a' #=> nil
```

In the above example, trying to invoke a method on the returned value will give a compile time error unless both `Int32` and `Nil` define that method:

```ruby
str = "Hello world"
idx = str.index 'e'
idx + 1 # Error: undefined method '+' for Nil
```

The language and the standard library provide short, readable, easy ways to deal with `nil`:

```ruby
str = "Hello world"
idx1 = str.index('e') || 0 # 0 if nil

idx2 = str.index('a')
if idx2
  idx2 + 1 # Compiles: idx2 can't be nil here
end

idx3 = str.index('o').not_nil! # Tell the compiler that we
                               # are sure the returned value
                               # is not nil: raises a
                               # runtime exception if our
                               # assumption doesn't hold.
```
