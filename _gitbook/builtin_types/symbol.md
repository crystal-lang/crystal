# Symbol

A symbol is a constant that is identified by a name without you having to give it a numeric value.

```ruby
:hello
:welcome
:"symbol with spaces"
```

Internally a symbol is represented as an `Int32`, so it's very efficient.

You can't dynamically create symbols: when you compile your program each symbol gets assigned a unique number.

You can turn a `Symbol` to a `String` with the `to_s` method:

```ruby
:hello.to_s #=> "hello"
```
