---
layout: post
title: Null Pointer Exception
thumbnail: NP
summary: Crystal doesn't let you have a Null Pointer Exception
author: asterite
---

Null pointer exceptions, also known as NPEs, are pretty common errors.

<ul class="goals">
  <li>In Java: java.lang.NullPointerException</li>
  <li>In Ruby: undefined method '...' for nil:NilClass</li>
  <li>In Python: AttributeError: 'NoneType' object has no attribute '...'</li>
  <li>In C#: Object reference not set to an instance of an object</li>
  <li>In C/C++: segmentation fault</li>
</ul>

Heck, two days ago I couldn't buy a bus ticket because I got a nice "Object reference not set to an instance of an object" in the payment page.

The good news? **Crystal doesn't allow you to have null pointer exceptions**.

Let's start with the simplest example:

{% highlight ruby %}
nil.foo
{% endhighlight %}

Compiling the above program gives this error:

<pre class="code">
Error in foo.cr:1: undefined method 'foo' for Nil

nil.foo
    ^~~
</pre>

`nil`, the only instance of the [Nil](https://github.com/manastech/crystal/blob/master/src/nil.cr) class, behaves just like any other class in Crystal.
And since it doesn't have a method named "foo", an error is issued **at compile time**.

Let's try with a slightly more complex, but made up, example:

{% highlight ruby %}
class Box
  getter :value

  def initialize(value)
    @value = value
  end
end

def make_box(n)
  case n
  when 1, 2, 3
    Box.new(n * 2)
  when 4, 5, 6
    Box.new(n * 3)
  end
end

n = ARGV.length
box = make_box(n)
puts box.value
{% endhighlight %}

Can you spot the bug?

Compiling the above program, Crystal says:

<pre class="code">
Error in foo.cr:20: undefined method 'value' for Nil

puts box.value
         ^~~~~

================================================================================

Nil trace:

  foo.cr:19

    box = make_box n
    ^

  foo.cr:19

    box = make_box n
          ^~~~~~~~

  foo.cr:9

    def make_box(n)
        ^~~~~~~~

  foo.cr:10

      case n
      ^
</pre>

Not only it tells you that you might have a null pointer exception (in this case, when n is not one of 1, 2, 3, 4, 5, 6),
but it also shows you where the `nil` originated. It's in the `case` expression, which has a default empty `else` clause, which has a `nil` value.

One last example, which might well be real code:

{% highlight ruby %}
require "socket"

# Create a new TCPServer at port 8080
server = TCPServer.new(8080)

# Accept a connection
socket = server.accept

# Read a line and output it capitalized
puts socket.gets.capitalize
{% endhighlight %}

Can you spot the bug now? It turns out that TCPSocket#gets
([IO#gets](https://github.com/manastech/crystal/blob/master/src/io.cr#L52), actually),
returns `nil` at the end of the file or, in this case, when the connection is closed.
So `capitalize` might be called on `nil`.

And Crystal prevents you from writing such a program:

<pre class="code">
Error in foo.cr:10: undefined method 'capitalize' for Nil

puts socket.gets.capitalize
                 ^~~~~~~~~~

================================================================================

Nil trace:

  std/file.cr:35

      def gets
          ^~~~

  std/file.cr:40

        length > 0 ? String.from_cstr(buffer) : nil
        ^

  std/file.cr:40

        length > 0 ? String.from_cstr(buffer) : nil
                                                ^
</pre>

To prevent this error, you can do the following:

{% highlight ruby %}
require "socket"

server = TCPServer.new(8080)
socket = server.accept
line = socket.gets
if line
  puts line.capitalize
else
  puts "Nothing in the socket"
end
{% endhighlight %}

This last program compiles fine. When you use a variable in an `if`'s condition, and because the only
falsy values are `nil` and `false`, Crystal knows that `line` can't be nil inside the "then" part of the `if`.

This is both expressive and executes faster, because it's not needed to check for `nil` values at runtime at every method call.

To conclude this post, one last thing left to say is that while porting the Crystal parser from
Ruby to
[Crystal](https://github.com/manastech/crystal/blob/master/src/compiler/crystal/parser.cr), Crystal refused to compile
because of a possible null pointer exception. And it was correct. So in a way, Crystal found a bug in itself :-)
