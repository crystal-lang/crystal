# Reference

`Reference` is the base class of classes you create in your program. It is set as a class' superclass when you don't specify one:

```ruby
class Foo # < Reference
end
```

Invoking `new` on a `Reference` allocates a new instance on the heap. The instance's memory is garbage-collected when the instance is no longer referred by any other entity in the program.

The `object_id` method gives you the address of the object in memory.

```ruby
class Person
  getter name

  def initialize(@name)
  end
end

person = Person.new "John"

ptr = Pointer(Person).new(person.object_id)

other_person = ptr as Person
other_person.name #=> John
```

A reference type is passed by reference: when passing it to methods or returning it from methods, a pointer is actually passed.
