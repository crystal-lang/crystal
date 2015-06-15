# Macro methods

Macro defs allow you to define a method for a class hierarchy and have that method be evaluated at the end of the type-inference phase, as a macro, where type information is known, for each concrete subtype. For example:

```ruby
class Object
  macro def instance_vars_names : Array(String)
    {{ @type.instance_vars.map &.name.stringify }}
  end
end

class Person
  def initialize(@name, @age)
  end
end

person = Person.new "John", 30
person.instance_vars_names #=> ["name", "age"]
```

Note that in the case of macro defs you need to specify the return type.

