# Return types

A method's return type is always inferred by the compiler. However, you might want to specify it for two reasons:

1. To make sure that the method returns the type that you want
2. To make it appear in documentation comments

For example:

```ruby
def some_method : String
  "hello"
end
```

The return type follows the [type grammar](type_grammar.html).
