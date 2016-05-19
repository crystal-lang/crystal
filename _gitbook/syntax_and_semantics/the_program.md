# The Program

The program is a global object in which you can define types, methods and file-local variables.

```crystal
# Defines a method in the program
def add(x, y)
  x + y
end

# Invokes the add method in the program
add(1, 2) #=> 3
```

A method's value is the value of its last expression, there's no need for explicit `return` expressions. However, explicit `return` are possible:

```crystal
def even?(num)
  if num % 2 == 0
    return true
  end

  return false
end
```

When invoking a method without a receiver, like `add(1, 2)`, it will be searched in the program if not found in the current type or any of its ancestors.

```crystal
def add(x, y)
  x + y
end

class Foo
  def bar
    # invokes the program's add method
    add(1, 2)

    # invokes Foo's baz method
    baz(1, 2)
  end

  def baz(x, y)
    x * y
  end
end
```

If you want to invoke the program's method, even though the current type defines a method with the same name, prefix the call with `::`:

```crystal
def baz(x, y)
  x + y
end

class Foo
  def bar
    baz(4, 2) #=> 2
    ::baz(4, 2) #=> 6
  end

  def baz(x, y)
    x - y
  end
end
```

Variables declared in a program are not visible inside methods:

```crystal
x = 1

def add(y)
  x + y # error: undefined local variable or method 'x'
end

add(2)
```

Parentheses in method invocations are optional:

```crystal
add 1, 2 # same as add(1, 2)
```

## Main code

Main code, the code that is run when you compile and run a program, can be written directly in a source file without the need to put it in a special "main" method:

```crystal
# This is a program that prints "Hello Crystal!"
puts "Hello Crystal!"
```

Main code can also be inside type declarations:

```crystal
# This is a program that prints "Hello"
class Hello
  # 'self' here is the Hello class
  puts self
end
```
