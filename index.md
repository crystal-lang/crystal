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

Interested? Read the [introduction](https://github.com/manastech/crystal/wiki/Introduction) or the [docs for developers](https://github.com/manastech/crystal/wiki/Developers).

Questions or suggestions? Ask in our [Google Group](https://groups.google.com/forum/?fromgroups#!forum/crystal-lang)

#### Latest entries from our blog:

{% for post in site.posts %}
* [{{ post.title }}]({{ post.url }})
{% endfor %}