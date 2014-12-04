# Methods and instance variables

We can simplify our constructor by using a shorter syntax for assigning a method argument to an instance variable:

``` ruby
class Person
  def initialize(@name)
    @age = 0
  end
end
```

Right now, we can't do much with a person: create it with a name, ask for its name and for its age, which will always be zero. So lets add a method that makes a person become older:

``` ruby
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

``` ruby
class Person
  def initialize(@name)
    @age = 0
  end
end

class Person
  def become_older
    @age += 1
  end
end
```

If you redefine a method, the last once will take precedence.

``` ruby
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

To further simply our program, we can use some [macros](macros.html):

``` ruby
class Person
  # This is the same as writing:
  #
  #   def name
  #     @name
  #   end
  getter name
  getter age

  def initialize(@name)
    @age = 0
  end

  def become_older
    @age += 1
  end
end
```
