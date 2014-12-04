# Constants

You can also declare constants inside a `lib` declaration:

```ruby
@[Link("pcre")]
lib PCRE
  INFO_CAPTURECOUNT = 2
end

PCRE::INFO_CAPTURECOUNT #=> 2
```
