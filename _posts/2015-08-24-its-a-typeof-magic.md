---
layout: post
title: It's a typeof magic
summary: It's magic!
thumbnail: t
author: asterite
---

## The story of typeof

The story of the `typeof` expression begins with array literals. In Crystal you can write

{% highlight ruby %}
array = [1, 2, 3]
{% endhighlight ruby %}

and the compiler will infer that the array is an `Array(Int32)`, meaning it can only contain
32 bits integers. And you can also write:

{% highlight ruby %}
array = [1, 'a', true]
{% endhighlight ruby %}

and the compiler will infer that it's an `Array(Int32 | Char | Bool)`, where `Int32 | Char | Bool`
means the union of those types: the array can hold any of those type at any point during the
program's execution.

Literals in the language, like array, hash and regular expression (regex) literals, are simple syntax rewrites to
regular standard library calls. In the case of a regex, this:

{% highlight ruby %}
/fo(o+)/
{% endhighlight ruby %}

is rewritten to:

{% highlight ruby %}
Regex.new("fo(o+)")
{% endhighlight ruby %}

The rewrite of array literals needs a bit more thought. Arrays are generic, meaning that they are parameterized
with a type `T` that specifies what type they can hold, like the `Array(Int32)` and `Array(Int32 | Char | Bool)`
mentioned earlier. The non-literal way to create one is:

{% highlight ruby %}
Array(Int32 | Char | Bool).new
{% endhighlight ruby %}

In the case of an array literal we need the type to be the union type of all the elements in the array literal.
And so, `typeof` was born. In the beginning this was called `type merge` and it was a compiler internal thing
that you couldn't express (there was no syntax for it), but the compiler used it for these literals. An
example rewrite:

{% highlight ruby %}
array = [1, 'a', true]

# Rewritten to this, where <type_merge>(exp1, exp2, ...) computes
# the union type of the expressions:
Array(<type_merge>(1, 'a', true)).build(3) do |buffer|
  buffer[0] = 1
  buffer[1] = 'a'
  buffer[2] = true
  3
end
{% endhighlight ruby %}

Now this literal is invoking a [regular method](http://crystal-lang.org/api/Array.html#build%28capacity%20%3A%20Int%2C%20%26block%29-class-method)
to build an array. The catch is that you couldn't write this: `<type_merge>` is only the representation of this internal node
that allows you to compute a type, but if you wrote the above you would get a syntax error.

We later decided that because this `<type_merge>` node worked pretty well, and we wanted literals to have no magic,
to let users use this `<type_merge>` node, and named it `typeof`, because this name is pretty familiar in other languages. Now
writing this:

{% highlight ruby %}
array = [1, 'a', true]
{% endhighlight ruby %}

and this:

{% highlight ruby %}
Array(typeof(1, 'a', true)).build(3) do |buffer|
  buffer[0] = 1
  buffer[1] = 'a'
  buffer[2] = true
  3
end
{% endhighlight ruby %}

are exactly equivalent: there's no magic (but of course the first syntax is much easier to write and read).

Little did we know that `typeof` would bring a lot of power to the language.

## Simple uses of typeof

One obvious use-case of typeof is to ask the compiler the inferred type of an expression. For example:

{% highlight ruby %}
puts typeof(1) #=> Int32
puts typeof([1, 2, 3].map &.to_s) #=> Array(String)
{% endhighlight ruby %}

At this point you might think that `typeof(exp)` is similar to `exp.class`. However,
the first gives you the compile-time type, while the second gives you the runtime type:

{% highlight ruby %}
exp = rand(0..1) == 0 ? 'a' : true
puts typeof(exp) #=> Char | Bool
puts exp.class   #=> Char (or Bool, depending on the chosen random value)
{% endhighlight ruby %}

Another simple use case is to create a type based on another object's type:

{% highlight ruby %}
hash = {1 => 'a', 2 => 'b'}
other_hash = typeof(hash).new #:: Hash(Int32, Char)
{% endhighlight ruby %}

In this way we can avoid repeating or hardcoding a type name.

But these are too simple to be interesting.

## Advanced uses of typeof

Let's write the `Array#compact` method. This method returns an `Array` where `nil` instances are removed.
Of course, if we start with an `Array(Int32 | Nil)`, that is, an array of integers and nils, we want to
end with an `Array(Int32)`.

The type grammar allows creating unions. For example `Int32 | Char` creates a union of `Int32` and `Char`.
However, there's no way to subtract types. There's no `T - Nil` syntax. But, using `typeof`, we can still
write this method.

First, we define a method whose type will be the one we want:

{% highlight ruby %}
def not_nil(exp)
  if exp.is_a?(Nil)
    raise "oops, nil"
  else
    exp
  end
end
{% endhighlight ruby %}

If `exp` is `Nil` we raise an exception, otherwise we return `exp`. Let's check its type:

{% highlight ruby %}
puts typeof(not_nil(1))   #=> Int32
puts typeof(not_nil(nil)) #=> NoReturn
{% endhighlight ruby %}

Thanks to the way [if var.is_a?(...)](http://crystal-lang.org/docs/syntax_and_semantics/if_varis_a.html) works,
when we give it something that's not `nil` it tells us that the type is that same type. But when we give it
`nil`, the only branch in the `if` that can be executed is the `raise` one. Now, `raise` has this `NoReturn`
type, which basically means there's no value returned by that expression... because it raises an exception!
Another expression that has `NoReturn` is, for example, `exit`.

Let's try and give `not_nil` something that's a union type:

{% highlight ruby %}
element = rand(0..1) == 0 ? 1 : nil
puts typeof(element)          #=> Int32 | Nil
puts typeof(not_nil(element)) #=> Int32
{% endhighlight ruby %}

Note that the `NoReturn` type is gone: the "expected" type of the last expression would be `Int32 | NoReturn`, that
is, the union of the possible types of the method. However, `NoReturn` doesn't have a tangible value,
so mixing `NoReturn` with any type `T` basically gives you `T` back. Because, if the `not_nil` method
succeeds (that is, it doesn't raise), you will get an integer back, otherwise an exception will be bubbled
through the stack.

Now we are ready to implement the compact method:

{% highlight ruby %}
class Array
  def compact
    result = Array(typeof(not_nil(self[0]))).new
    each do |element|
      result << element unless element.is_a?(Nil)
    end
    result
  end
end

ary = [1, nil, 2, nil, 3]
puts typeof(ary)       #=> Array(Int32 | Nil)

compacted = ary.compact
puts compacted         #=> [1, 2, 3]
puts typeof(compacted) #=> Array(Int32)
{% endhighlight ruby %}

The magical line is the first one in the method:

{% highlight ruby %}
Array(typeof(not_nil(self[0]))).new
{% endhighlight ruby %}

We create an array whose type is the type that results of invoking `not_nil` on the first element of the array. Note
that the compiler doesn't know what types are in each position in an array, so using `0`, `1` or `123` would be the same.

In this way we were able to forge a type that excludes `Nil` without needing to extend the type grammar: the compiler's
machinery for the type inference algorithm is all we needed.

But this is still simple. Let's move on to something **really** interesting and fun.

## typeof sorcery

Our next task is to implement `Array#flatten`. This method returns an `Array` that is a one-dimensional flattening
of the original array (recursively). That is, for every element that is an array, extract its elements into this new
array.

Note that this has to work recursively. Let's see some expected behaviour:

{% highlight ruby %}
ary1 = [1, [2, [3], 'a']]
puts typeof(ary1)             #=> Array(Int32 | Array(Int32 | Array(Int32) | Char))

ary1_flattened = ary1.flatten
puts ary1_flattened           #=> [1, 2, 3, 'a']
puts typeof(ary1_flattened)   #=> Array(Int32 | Char)
{% endhighlight ruby %}

Like before, let's start by writing a method whose type will have the type that we need for the flattened
array:

{% highlight ruby %}
def flatten_type(object)
  if object.is_a?(Array)
    flatten_type(object[0])
  else
    object
  end
end

puts typeof(flatten_type(1))                          #=> Int32
puts typeof(flatten_type([1, [2]]))                   #=> Int32
puts typeof(flatten_type([1, [2, ['a', 'b']]]))       #=> Int32 | Char
{% endhighlight ruby %}

The method is simple: if the object is an array, we want the flatten type of any of its elements. Otherwise,
the type is that of the object.

And with this, we are ready to implement flatten:

{% highlight ruby %}
class Array
  def flatten
    result = Array(typeof(flatten_type(self))).new
    append_flattened(self, result)
    result
  end

  private def append_flattened(object, result)
    if object.is_a?(Array)
      object.each do |sub_object|
        append_flattened(sub_object, result)
      end
    else
      result << object
    end
  end
end
{% endhighlight ruby %}

In this second example we were able to forge a type that is an array flattening.

## Conclusion

In the end, there's nothing really magical about `typeof`. It just lets you query and use the compiler's
ability to infer the type of an expression really well.

In the previous examples we were able to forge types from other types with regular stuff: types and
methods. There's nothing new to learn, there's no special syntax for talking about types. And this
is good, because it's simple, but powerful.
