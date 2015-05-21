# Generics
One of the things that might throw off the less polyglot rubyists when taking a look at Crystal code is generics. As a tl;dr of the wikipedia article, a generic class is a class that, when instantiated, must be told explicitly or implicitly its type or types.
This is easier to understand with a concrete example, such as the Array class:
```
class Array(T)
end
```
T is a special kind of variable, a reference to the type of the array that will later be created which we don't know at the moment of writing the generic class. The name "T" is a convention, short for type; it might as well be called TYPE, or Z, or any other unused constant. If you try to create an instance of Array you usually need to tell the compiler the type of the objects it will contain:
```
Array(String).new # or "[] of String"
Array(Symbol).new # or "[] of Symbol"
Array(Array).new # or "[] of Array"
```

*Note*: An array (or hash, or range) literal with elements in it is a bit of a special case. It will automatically have its type set to whatever it contains without having to declare it explicitly.

The type of T is important here for at least two reasons:
In Array's case, the class is implemented by a Pointer class (actually a struct, but that's another story) that is itself generic, so the type of the Array will also be the type of its internal Pointer.
More relevant to the subject of generic classes, many methods accept only objects that are of the array's type and a method missing exception will be raised (at compile time) if given anything else.
Example:
```
class Array(T)
  def unshift(obj : T)
    # body omitted
  end
end
```
Everywhere in the definition of a generic class you can use that "T" to reference the type of the class. In this case, it's used to define a method which will only accept an argument of type T, whatever that might be.
Let's see what happens if you try to call #unshift with an object that is not of the array's type:
```
  array = Array(String).new
  array.unshift(5)

  # no overload matches 'Array(String)#unshift' with types Int32
  # Overloads are:
  # - Array(String)#unshift(obj : String)
```
A generic class can also have an union of two or more types as a type variable, which is written in this way:
`Array(String | Symbol).new # or "[] of String | Symbol"`
When calling a method on an any element of an array such as the one above the compiler will raise a method missing exception unless both String and Symbol implement it:
`[:abc, "bcd"].first.reverse # undefined method 'reverse' for Symbol`
This is because as far as the compiler is concerned, the return value of `#first` could be either a String or a Symbol and Symbol doesn't implement a #reverse method.
A method can also explicitly reference an "unknown" type that is not necessarily the class' type. A good example is #map:
```
def map(&block : T -> U)
  ary = [] of U
  each { |e| ary << yield e }
  ary
end
```
That block argument can be read as "a block that yields elements of type T and returns elements of type U". As with "T", the name "U" is a convention, totally arbitrary. #map then is able to create an array of the type that the block returns which might be different from T.
A generic class can have more than one type, like Hash:
```
class Hash(K, V)
end
```
In this case K stands for the type of the keys, and V for the type of the values.
```
hash = Hash(Symbol, String) # or "{} of Symbol => String"
hash[:name] = "Exilor"
```
Range too used to have two and will have two again when 0.6.2 is released:
```
struct Range(B, E)
end
```
B represents the first element (begin) and E the last (end).
Modules can also be generic. Enumerable and Comparable most notably. The reason why a module would be generic is perhaps more obvious when you see how `Enumerable#to_a` is implemented:
```
module Enumerable(T)
  def to_a
    ary = [] of T
    each { |e| ary << e }
    ary
  end
end
```
Because `#to_a` creates an empty array and then fills it with whatever #each yields, it needs to know what type (T) it has to create an array of.
