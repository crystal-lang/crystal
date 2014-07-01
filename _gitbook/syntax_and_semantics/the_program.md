# The Program

The program is a global object in which you can define methods and file-local variables.

``` ruby
# Defines a method in the program
def add(x, y)
  x + y
end

# Invokes the add method in the program
add(1, 2)
```

When invoking a method without a receiver, like `add(1, 2)`, if the method is not found in the current type then it will be searched in the program.

```ruby
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

Variables declared in a program are not visible inside methods:

``` ruby
x = 1

def add(y)
  x + y # error: undefined local variable or method 'x'
end

add(2)
```
