# Inheritance

Every class except `Object`, the hierarchy root, inherits from another class (its superclass). If you don't specify one it defaults to `Reference` for classes and `Struct` for structs.

A class inherits all instance variables and all instance and class methods of a superclass, including its constructors (`new` and `initialize`).

```crystal
class Person
  def initialize(@name : String)
  end

  def greet
    puts "Hi, I'm #{@name}"
  end
end

class Employee < Person
end

employee = Employee.new "John"
employee.greet # "Hi, I'm John"
```

If a class defines a `new` or `initialize` then its superclass constructors are not inherited:

```crystal
class Person
  def initialize(@name : String)
  end
end

class Employee < Person
  def initialize(@name : String, @company_name : String)
  end
end

Employee.new "John", "Acme" # OK
Employee.new "Peter" # Error: wrong number of arguments
                     # for 'Employee:Class#new' (1 for 2)
```

You can override methods in a derived class:

```crystal
class Person
  def greet(msg)
    puts "Hi, #{msg}"
  end
end

class Employee < Person
  def greet(msg)
    puts "Hello, #{msg}"
  end
end

p = Person.new
p.greet "everyone" # "Hi, everyone"

e = Employee.new
e.greet "everyone" # "Hello, everyone"
```

Instead of overriding you can define specialized methods by using type restrictions:

```crystal
class Person
  def greet(msg)
    puts "Hi, #{msg}"
  end
end

class Employee < Person
  def greet(msg : Int32)
    puts "Hi, this is a number: #{msg}"
  end
end

e = Employee.new
e.greet "everyone" # "Hi, everyone"

e.greet 1 # "Hi, this is a number: 1"
```

## super

You can invoke a superclass' method using `super`:

```crystal
class Person
  def greet(msg)
    puts "Hello, "#{msg}"
  end
end

class Employee < Person
  def greet(msg)
    super # Same as: super(msg)
    super("another message")
  end
end
```

Without arguments nor parenthesis, `super` receives the same arguments as the method's arguments. Otherwise, it receives the arguments you pass to it.
