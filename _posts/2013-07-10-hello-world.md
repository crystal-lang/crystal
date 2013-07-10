---
layout: post
title: Hello World
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

# Create a new object
g = Greeter.new("world")

# Output "Hello World!"
g.salute
{% endhighlight %}

Or maybe with blocks:

{% highlight ruby %}
"Hello World".each_char do |char|
  print char
end
print '\n'
{% endhighlight %}
