# Methods and instance variables

We can simplify our constructor by using a shorter syntax for assigning a method argument to an instance variable:

```crystal
class Person
  def initialize(@name : String)
    @age = 0
  end
end
```

Right now, we can't do much with a person: create it with a name, ask for its name and for its age, which will always be zero. So lets add a method that makes a person become older:

```crystal
class Person
  def become_older
    @age += 1
  end
end

john = Person.new "John"
peter = Person.new "Peter"

john.age #=> 0

john.become_older
john.age #=> 1

peter.age #=> 0
```

Method names begin with a lowercase letter and, as a convention, only use lowercase letters, underscores and numbers.

As a side note, we can define `become_older` inside the original `Person` definition, or in a separate definition: Crystal combines all definitions into a single class. The following works just fine:

```crystal
class Person
  def initialize(@name : String)
    @age = 0
  end
end

class Person
  def become_older
    @age += 1
  end
end
```

## Redefining methods, and previous_def

If you redefine a method, the last definition will take precedence.

```crystal
class Person
  def become_older
    @age += 1
  end
end

class Person
  def become_older
    @age += 2
  end
end

person = Person.new "John"
person.become_older
person.age #=> 2
```

You can invoke the previously redefined method with `previous_def`:

```crystal
class Person
  def become_older
    @age += 1
  end
end

class Person
  def become_older
    previous_def
    @age += 2
  end
end

person = Person.new "John"
person.become_older
person.age #=> 3
```

Without arguments nor parenthesis, `previous_def` receives the same arguments as the method's arguments. Otherwise, it receives the arguments you pass to it.

## Catch-all initialization

Instance variables can also be initialized outside `initialize` methods:

```crystal
class Person
  @age = 0

  def initialize(@name : String)
  end
end
```

This will initialize `@age` to zero in every constructor. This is useful to avoid duplication, but also to avoid the `Nil` type when reopening a class and adding instance variables to it.

