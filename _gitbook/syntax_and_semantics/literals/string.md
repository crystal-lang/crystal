# String

A [String](http://crystal-lang.org/api/String.html) represents an immutable sequence of UTF-8 characters.

A String is typically created with a string literal, enclosing UTF-8 characters in double quotes:

```ruby
"hello world"
```

A backslash can be used to denote some characters inside the string:

```ruby
"\"" # double quote
"\\" # backslash
"\e" # escape
"\f" # form feed
"\n" # newline
"\r" # carriage return
"\t" # tab
"\v" # vertical tab
```

You can use a backslash followed by at most three digits to denote a code point written in octal:

```ruby
"\101" # == "A"
"\123" # == "S"
"\12"  # == "\n"
"\1"   # string with one character with code point 1
```

You can use a backslash followed by an *u* and four hexadecimal characters to denote a unicode codepoint written:

```ruby
"\u0041" # == "A"
```

Or you can use curly braces and specify up to four hexadecimal numbers:

```ruby
"\u{41}" # == "A"
```

A string can span multiple lines:

```ruby
"hello
      world" # same as "hello      \nworld"
```

Note that in the above example trailing and leading spaces, as well as newlines,
end up in the resulting string. To avoid this, you can split a string into multiple lines
by joining multiple literals with a backslash:

```ruby
"hello " \
"world, " \
"no newlines" # same as "hello world, no newlines"
```

Alterantively, a backlash followed by a newline can be inserted inside the string literal:

```ruby
"hello \
     world, \
     no newlines" # same as "hello world, no newlines"
```

In this case, leading whitespace is not included in the resulting string.

If you need to write a string that has many double quotes, parenthesis, or similar
characters, you can use alternative literals:

```ruby
# Supports double quotes and nested parenthesis
%(hello ("world")) # same as "hello (\"world\")"

# Supports double quotes and nested brackets
%[hello ["world"]] # same as "hello [\"world\"]"

# Supports double quotes and nested curlies
%{hello {"world"}} # same as "hello {\"world\"}"

# Supports double quotes and nested angles
%<hello <"world">> # same as "hello <\"world\">"
```

## Interpolation

To create a String with embedded expressions, you can use string interpolation:

```ruby
a = 1
b = 2
"sum = #{a + b}"        # "sum = 3"
```

This ends up invoking `Object#to_s(IO)` on each expression enclosed by `#{...}`.
