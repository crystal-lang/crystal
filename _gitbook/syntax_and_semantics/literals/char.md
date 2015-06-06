# Char

A [Char](http://crystal-lang.org/api/Char.html) represents a [Unicode](http://en.wikipedia.org/wiki/Unicode) [code point](http://en.wikipedia.org/wiki/Code_point).
It occupies 32 bits.

It is created by enclosing an UTF-8 character in single quotes.

```ruby
'a'
'z'
'0'
'_'
'あ'
```

You can use a backslash to denote some characters:

```ruby
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

```ruby
'\101' # == 'A'
'\123' # == 'S'
'\12'  # == '\n'
'\1'   # code point 1
```

You can use a backslash followed by an *u* and four hexadecimal characters to denote a unicode codepoint written:

```ruby
'\u0041' # == 'A'
```

Or you can use curly braces and specify up to six hexadecimal numbers (0 to 10FFFF):

```ruby
'\u{41}'    # == 'A'
'\u{1F52E}' # == '🔮'
```
