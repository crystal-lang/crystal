# Symbol

A [Symbol](http://crystal-lang.org/api/Symbol.html) is a constant that is identified by a name without you having to give it a numeric value.

```ruby
:hello
:good_bye

# With spaces and symbols
:"symbol with spaces"

# Ending with question and exclamation marks
:question?
:exclamation!

# For the operators
:+
:-
:*
:/
:==
:<
:<=
:>
:>=
:!
:!=
:=~
:!~
:&
:|
:^
:~
:**
:>>
:<<
:%
:[]
:[]?
:[]=
:<=>
:===
```

Internally a symbol is represented as an `Int32`.
