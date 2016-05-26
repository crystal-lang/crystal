# String

A [String](http://crystal-lang.org/api/String.html) represents an immutable sequence of UTF-8 characters.

A String is typically created with a string literal, enclosing UTF-8 characters in double quotes:

```crystal
"hello world"
```

A backslash can be used to denote some characters inside the string:

```crystal
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

```crystal
"\101" # == "A"
"\123" # == "S"
"\12"  # == "\n"
"\1"   # string with one character with code point 1
```

You can use a backslash followed by an *u* and four hexadecimal characters to denote a unicode codepoint written:

```crystal
"\u0041" # == "A"
```

Or you can use curly braces and specify up to six hexadecimal numbers (0 to 10FFFF):

```crystal
"\u{41}"    # == "A"
"\u{1F52E}" # == "🔮"
```

A string can span multiple lines:

```crystal
"hello
      world" # same as "hello\n      world"
```

Note that in the above example trailing and leading spaces, as well as newlines,
end up in the resulting string. To avoid this, you can split a string into multiple lines
by joining multiple literals with a backslash:

```crystal
"hello " \
"world, " \
"no newlines" # same as "hello world, no newlines"
```

Alternatively, a backlash followed by a newline can be inserted inside the string literal:

```crystal
"hello \
     world, \
     no newlines" # same as "hello world, no newlines"
```

In this case, leading whitespace is not included in the resulting string.

If you need to write a string that has many double quotes, parenthesis, or similar
characters, you can use alternative literals:

```crystal
# Supports double quotes and nested parenthesis
%(hello ("world")) # same as "hello (\"world\")"

# Supports double quotes and nested brackets
%[hello ["world"]] # same as "hello [\"world\"]"

# Supports double quotes and nested curlies
%{hello {"world"}} # same as "hello {\"world\"}"

# Supports double quotes and nested angles
%<hello <"world">> # same as "hello <\"world\">"
```

## Heredoc

You can also use a "heredoc" for creating string:

```crystal
<<-XML
<parent>
  <child />
</parent>
XML
```

A "heredoc" is written with `<<-IDENT`, where `IDENT` is an identifier, a sequence of letters and numbers that must start with a letter. The "heredoc" finishes in the line that starts with `IDENT`, ignoring leading whitespace.

Leading whitespace is removed from the heredoc contents according to the number of whitespace that this last `IDENT` has. For example:

```crystal
# Same as "Hello\n  world"
<<-STRING
  Hello
    world
  STRING

# Same as "  Hello\n    world"
<<-STRING
    Hello
      world
  STRING
```

## Interpolation

To create a String with embedded expressions, you can use string interpolation:

```crystal
a = 1
b = 2
"sum = #{a + b}"        # "sum = 3"
```

This ends up invoking `Object#to_s(IO)` on each expression enclosed by `#{...}`.

## Without interpolation nor escapes

To create a String without interpolation nor escapes use `%q`:

```crystal
%q(hello \n #{world}) # => "hello \\n \#{world}"
```

Delimiters for `%q(...)` can also be `{}`, `[]` and `<>`.

Heredoc without interpolation nor escapes is also possible, simply enclose the heredoc delimiter in single quotes:

```crystal
<<-'HERE'
hello \n #{world}
HERE
```
