---
layout: default
---

### Welcome to Crystal

Crystal is a programming language with the following goals:

* Ruby-inspired syntax.
* Never have to specify the type of a variable or method argument.
* Be able to call C code by writing bindings to it in Crystal.
* Have compile-time evaluation and generation of code, to avoid boilerplate code.
* Compile to efficient native code.

It looks like this:

{% highlight ruby %}
# Compute prime numbers up to 100 with the Sieve of Eratosthenes
max = 100

sieve = Array.new(max, true)
sieve[0] = false

(2...max).each do |i|
  if sieve[i]
    (2 * i).step(max - 1, i) do |j|
      sieve[j] = false
    end
  end
end

sieve.each_with_index do |prime, number|
  puts number if prime
end
{% endhighlight %}

Interested? Read the [introduction](https://github.com/manastech/crystal/wiki/Introduction) or the [docs for developers](https://github.com/manastech/crystal/wiki/Developers).

Questions or suggestions? Ask in our [Google Group](https://groups.google.com/forum/?fromgroups#!forum/crystal-lang) or join our IRC channel #crystal-lang at irc.freenode.net

#### Latest entries from our blog:

{% for post in site.posts %}
* [{{ post.title }}]({{ post.url }})
{% endfor %}
