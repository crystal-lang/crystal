---
layout: post
title: Hello World
thumbnail: Hi
summary: The famous Hello World program written in different ways in Crystal
author: asterite, waj
---

This is the simplest way to write the Hello World program in Crystal:

{% highlight ruby %}
puts "Hello World"
{% endhighlight %}

But if you feel like it, you can also use some object oriented programming:

{% highlight ruby %}
class Greeter
  def initialize(name)
    @name = name.capitalize
  end

  def salute
    puts "Hello #{@name}!"
  end
end

g = Greeter.new("world")
g.salute
{% endhighlight %}

Or maybe with blocks:

{% highlight ruby %}
"Hello World".each_char do |char|
  print char
end
print '\n'
{% endhighlight %}

Each alternative might have a different performance, but luckily all of them are pretty expressive.

Ok, but what's the purpose of learning a language if we cannot run the damn thing? Let's see how we do this with Crystal
(and let's assume you already have it [installed](https://github.com/manastech/crystal/wiki/Introduction#installation)).

First create a file `hello.cr` containing your preferred choice of the previous examples.
Then type in the console:

<pre class="code">
$ bin/crystal hello.cr
$ ./hello
Hello World
$
</pre>

The compiled output is a standalone executable without any specific runtime dependency. Neat! Isn't it?
