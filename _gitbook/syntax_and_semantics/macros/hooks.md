# Hooks

Special macros exist that are invoked in some situations, as hooks:
`inherited`, `included` and `method_missing`.
* `inherited` will be invoked at compile-time when a subclass is defined. `@type` becomes the inherited type.
* `included` will be invoked at compile-time when a module is included. `@type` becomes the including type.
* `extended` will be invoked at compile-time when a module is extended. `@type` becomes the extending type.
* `method_missing` will be invoked at compile-time when a method is not found.

Example of `inherited`:

```ruby
class Parent
  macro inherited
    def {{@type.name.downcase.id}}
      1
    end
  end
end

class Child < Parent
end

Child.new.child #=> 1
```

Example of `method_missing`:

```ruby
macro method_missing(name, args, block)
  print "Got ", {{name.id.stringify}}, " with ", {{args.length}}, " arguments", '\n'
end

foo          # Prints: Got foo with 0 arguments
bar 'a', 'b' # Prints: Got bar with 2 arguments
```
