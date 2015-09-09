# Constants

You can also declare constants inside a `lib` declaration:

```crystal
@[Link("pcre")]
lib PCRE
  INFO_CAPTURECOUNT = 2
end

PCRE::INFO_CAPTURECOUNT #=> 2
```
