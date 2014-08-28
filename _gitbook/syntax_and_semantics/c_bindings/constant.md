# constant

You can also declare constants inside a `lib` declaration:

```ruby
lib PCRE("pcre")
  INFO_CAPTURECOUNT = 2
end

PCRE::INFO_CAPTURECOUNT #=> 2
```
