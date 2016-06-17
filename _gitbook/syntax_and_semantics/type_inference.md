# Type inference

**Note**: this applies to the next version of Crystal (0.16.0). Before this version global type inference takes the whole program and all uses into account.

Crystal's philosophy is to require as few type annotations as possible. However, some type annotatinos are required.

Consider a class definition like this:

```crystal
class Person
  def initialize(@name)
    @age = 0
  end
end
```

We can quickly see that `@age` is an integer, but we don't know what's the type of `@name`. The compiler could infer its type from all uses of the `Person` class. However, doing so has a few issues:

* The type is not obvious for a human reading the code: she would also have to check all uses of `Person` to find this out.
* Some compiler optimizations, like having to analyze a method just once, and incremental compilation, are near impossible to do.

As a code base grows, these issues gain more relevance: understanding a project becomes harder, and compile times become unbearable.

For this reason, Crystal needs to know, in an obvious way (as obvious as to a human), the types of instance, [class](class_variables.html) and [global](global_variables.html) variables.

There are several ways to let Crystal know this.

## Use an explicit type annotation

The easiest, but probably most tedious, way is to use explicit type annotations.

```crystal
class Person
  @name : String
  @age : Int32

  def initialize(@name)
    @age = 0
  end
end
```

## Don't use an explicit type annotation

If you omit an explicit type annotation the compiler will try to infer the type of instance, class and global variables using a bunch of syntactic rules.

For a given instance/class/global variable, when a rule can be applied and a type can be guessed, the type is added to a set. When no more rules can be applied, the inferred type will be the [union](union_types.html) of those types. Additionally, if the compiler infers that an instance variable isn't always initialized, it will also include the [Nil](literals/nil.html) type.

The rules are many, but usually the first three are most used. There's no need to remember them all. If the compiler gives an error saying that the type of an instance variable can't be inferred you can always add an explicit type annotation.

The following rules only mention instance variables, but they apply to class and global variables as well. They are:

### 1. Assigning a literal value

When a literal is assigned to an instance variable, the literal's type is added to the set. All [literals](literals.html) have an associated type.

In the following example, `@name` is inferred to be `String` and `@age` to be `Int32`.

```crystal
class Person
  def initialize
    @name = "John Doe"
    @age = 0
  end
end
```

This rule, and every following rule, will also be applied in methods other than `initialize`. For example:

```crystal
class SomeObject
  def lucky_number
    @lucky_number = 42
  end
end
```

In the above case, `@lucky_number` will be inferred to be `Int32 | Nil`: `Int32` because 42 was assigned to it, and `Nil` because it wasn't assigned in all of the class' initialize methods.

### 2. Assigning the result of invoking the class method `new`

When an expression like `Type.new(...)` is assigned to an instance variable, the type `Type` is added to the set.

In the following example, `@address` is inferred to be `Address`.

```crystal
class Person
  def initialize
    @address = Address.new("somewhere")
  end
end
```

This also is applied to generic types. Here `@values` is inferred to be `Array(Int32)`.

```crystal
class Something
  def initialize
    @values = Array(Int32).new
  end
end
```

**Note**: a `new` method might be redefined by a type. In that case the inferred type will be the one returned by `new`, if it can be inferred using some of the next rules.

### 3. Assigning a variable that is a method argument with a type restriction

In the following example `@name` is inferred to be `String` because the method argument `name` has a type restriction of type `String`, and that argument is assigned to `@name`.

```crystal
class Person
  def initialize(name : String)
    @name = name
  end
end
```

Note that the name of the method argument is not important, this works as well:

```crystal
class Person
  def initialize(obj : String)
    @name = obj
  end
end
```

Using the shorter syntax to assign an instance variable from a method argument has the same effect:

```crystal
class Person
  def initialize(@name : String)
  end
end
```

Also note that the compiler doesn't check whether method argument is reassigned a different value:

```crystal
class Person
  def initialize(name : String)
    name = 1
    @name = name
  end
end
```

In the above case, the compiler will still infer `@name` to be `String`, and later will give a compile time error, when fully typing that method, saying that `Int32` can't be assigned to a variable of type `String`. Use an explicit type annotation if `@name` isn't supposed to be a `String`.

### 4. Assigning the result of a class method that has a return type annotation

In the following example, `@address` is inferred to be `Address`, because the class method `Address.unknown` has a return type annotation of `Address`.

```crystal
class Person
  def initialize
    @address = Address.unknown
  end
end

class Address
  def self.unknown : Address
    new("unknown")
  end

  def initialize(@name : String)
  end
end
```

In fact, the above code doesn't need the return type annotation in `self.unknown`. The reason is that the compiler will also look at a class method's body and if it can apply one of the previous rules (it's a `new` method, or it's a literal, etc.) it will infer the type from that expression. So, the above can be simply written like this:

```crystal
class Person
  def initialize
    @address = Address.unknown
  end
end

class Address
  # No need for a return type annotation here
  def self.unknown
    new("unknown")
  end

  def initialize(@name : String)
  end
end
```

This extra rule is very convenient because it's very common to have "constructor-like" class methods in addition to `new`.

### 5. Assigning a variable that is a method argument with a default value

In the following example, because the default value of `name` is a string literal, and it's later assigned to `@name`, `String` will be added to the set of inferred typed.

```crystal
class Person
  def initialize(name = "John Doe")
    @name = name
  end
end
```

This of course also works with the short syntax:

```crystal
class Person
  def initialize(@name = "John Doe")
  end
end
```

The default value can also be a `Type.new(...)` method or a class method with a return type annotation.

### 6. Assigning the result of invoking a `lib` function

Because a [lib function](c_bindings/fun.html) must have explicit types, the compiler can use the return type when assigning it to an instance variable.

In the following example `@age` is inferred to be `Int32`.

```crystal
class Person
  def initialize
    @age = LibPerson.compute_default_age
  end
end

lib LibPerson
  fun compute_default_age : Int32
end
```

### 7. Using an `out` lib expression

Because a [lib function](c_bindings/fun.html) must have explicit types, the compiler can use the `out` argument's type, which should be a pointer type, and use the dereferenced type as a guess.

In the following example `@age` is inferred to be `Int32`.

```crystal
class Person
  def initialize
    LibPerson.compute_default_age(out @age)
  end
end

lib LibPerson
  fun compute_default_age(age_ptr : Int32*)
end
```

### Other rules

The compiler will try to be as smart as possible to require less explicit type annotations. For example, if assigning an `if` expression, type will be inferred from the `then` and `else` branches:

```crystal
class Person
  def initialize
    @age = some_condition ? 1 : 2
  end
end
```

Because the `if` above (well, technically a ternary operator, but it's similar to an `if`) has integer literals, `@age` is successfully inferred to be `Int32` without requiring a redundant type annotation.

Another case is `||` and `||=`:

```crystal
class SomeObject
  def lucky_number
    @lucky_number ||= 42
  end
end
```

In the above example `@lucky_number` will be inferred to be `Int32 | Nil`. This is very useful for lazily initialized variables.

Constants will also be followed, as it's pretty simple for the compiler (and a human) to do so.

```crystal
class SomeObject
  DEFAULT_LUCKY_NUMBER = 42

  def initialize(@lucky_number = DEFAULT_LUCKY_NUMBER)
  end
end
```

Here rule 5 (argument's default value) is used, and because the constant resolves to an integer literal, `@lucky_number` is inferred to be `Int32`.
