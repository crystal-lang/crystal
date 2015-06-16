# Overloading

We can define a `become_older` method that accepts a number indicating the years to grow:

```ruby
class Person
  def become_older
    @age += 1
  end

  def become_older(years)
    @age += years
  end
end

john = Person.new "John"
john.age #=> 0

john.become_older
john.age #=> 1

john.become_older 5
john.age #=> 6
```

That is, you can have different methods with the same name and different number of arguments and they will be considered as separate methods. This is called *method overloading*.

Methods overload by several criteria:

* The number of arguments
* The type restrictions applied to arguments
* Whether the method accepts a [block](blocks_and_procs.html) or not

For example, we can define four different `become_older` methods:

```ruby
class Person
  # Increases age by one
  def become_older
    @age += 1
  end

  # Increases age by the given number of years
  def become_older(years : Int32)
    @age += years
  end

  # Increases age by the given number of years, as a String
  def become_older(years : String)
    @age += years.to_i
  end

  # Yields the current age of this person and increases
  # its age by the value returned by the block
  def become_older
    @age += yield @age
  end
end

person = Person.new "John"

person.become_older
person.age #=> 1

person.become_older 5
person.age #=> 6

person.become_older "12"
person.age #=> 18

person.become_older do |current_age|
  current_age < 20 ? 10 : 30
end
person.age #=> 28
```

Note that in the case of the method that yields, the compiler figured this out because there's a `yield` expression. To make this more explicit, you can add a dummy `&block` argument at the end:

```ruby
class Person
  def become_older(&block)
    @age += yield @age
  end
end
```

In generated documentation the dummy `&block` method will always appear, regardless of you writing it or not.

Given the same number of arguments, the compiler will try to sort them by leaving the less restrictive ones to the end:

```ruby
class Person
  # First, this method is defined
  def become_older(age)
    @age += age
  end

  # Since "String" is more restrictive than no restriction
  # at all, the compiler puts this method before the previous
  # one when considering which overload matches.
  def become_older(age : String)
    @age += age.to_i
  end
end

person = Person.new "John"

# Invokes the first definition
person.become_older 20

# Invokes the second definition
person.become_older "12"
```

However, the compiler cannot always figure out the order because there isn't always a total ordering, so it's always better to put less restrictive methods at the end.
