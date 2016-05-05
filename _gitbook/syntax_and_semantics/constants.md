# Constants

Constants can be declared at the top level or inside other types. They must start with a capital letter:

```crystal
PI = 3.14

module Earth
  RADIUS = 6_371_000
end

PI #=> 3.14
Earth::RADIUS #=> 6_371_000
```

Although not enforced by the compiler, constants are usually named with all capital letters and underscores to separate words.

A constant definition can invoke methods and have complex logic:

```crystal
TEN = begin
  a = 0
  while a < 10
    a += 1
  end
  a
end

TEN #=> 10
```

A constant is initialized at the beginning of the program, before "main" code:

```crystal
# This assignment happens before the initialization of Foo::VALUE
ENV["HOME"] = "."

class Foo
  VALUE = ENV["HOME"]
end

Foo::VALUE # probably not "."
```

In those cases the best thing is to lazily initialize a class variable:

```crystal
ENV["HOME"] = "."

class Foo
  def self.value
    @@value ||= ENV["HOME"]
  end
end

Foo.value # "."
```

If a constant is not used, its initializer is never included in the final executable.
