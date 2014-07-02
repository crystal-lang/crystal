# Char

A `Char` represents a [Unicode](http://en.wikipedia.org/wiki/Unicode) [code point](http://en.wikipedia.org/wiki/Code_point). A char literal is enclosed with single quotes and contains a character encoded in `UTF-8`.

``` ruby
'a'
'z'
'0'
'_'
'あ'
```

You can use a backslash to denote some characters:

``` ruby
'\'' # single quote
'\\' # backslash
'\e' # escape
'\f' # form feed
'\n' # newline
'\r' # carriage return
'\t' # tab
'\v' # vertical tab
```

You can use a backslash followed by at most three digits to denote a code point written in octal:

``` ruby
'\101' # == 'A'
'\123' # == 'S'
'\12'  # == '\n'
'\1'   # code point 1
```

You can use a backslash followed by an `x` and hexadecimal characters to denote a code point written in hexadecimal:

``` ruby
'\x41' # == 'A'
```

You can get a `Char`'s code point by invoking the `ord` method on it.
