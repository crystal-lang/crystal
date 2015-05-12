# Range

A [Range](http://crystal-lang.org/api/Range.html) is typically constructed with a range literal:

```ruby
x..y  # an inclusive range, in mathematics: [x, y]
x...y # an exclusive range, in mathematics: [x, y)
```

An easy way to remember which one is inclusive and which one is exclusive it to think of the extra dot as if it pushes *y* further away, thus leaving it outside of the range.
