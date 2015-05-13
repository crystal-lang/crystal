# Regex

Regular expressions are represented by the [Regex](http://crystal-lang.org/api/Regex.html) class, which is usually created with a literal:

```ruby
foo_or_bar = /foo|bar/
heeello    = /h(e+)llo/
integer    = /\d+/
```

A regular expression literal is delimited by `/` and uses [PCRE](http://pcre.org/pcre.txt) syntax.

It can be followed by these modifiers:

* i: ignore case (PCRE_CASELESS)
* m: multiline (PCRE_MULTILINE)
* x: extended (PCRE_EXTENDED)

For example

```ruby
r = /foo/imx
```

Slashes must be escaped:

```ruby
slash = /\//
```

An alternative syntax is provided:

```ruby
r = %r(regex with slash: /)
```
