# Documenting code

Crystal documentation comments use a subset of [Markdown](https://daringfireball.net/projects/markdown/).

* Documentation should be positioned right above definitions of classes, modules, and methods. Leave no blanks between them.

```crystal
# A unicorn is a **legendary animal** (see the `Legendary` module) that has been
# described since antiquity as a beast with a large, spiraling horn projecting
# from its forehead.
class Unicorn
end

# Bad: This is not attached to any class.

class Legendary
end
```

* The documentation of a method is included into the method summary and the method details. The former includes only the first line, the latter includes the entire documentation. In short, it is preferred to:

  1. State a method's purpose or functionality in the first line.
  2. Supplement it with details and usages after that.

For instance:

``````crystal
# Returns the number of horns this unicorn has.
#
# ```
# Unicorn.new.horns # => 1
# ```
def horns
  @horns
end
``````

* Use the third person: `Returns the number of horns this unicorn has` instead of `Return the number of horns this unicorn has`.

* Parameter names should be *italicized* (surrounded with single asterisks `*` or underscores `_`):

```crystal
# Creates a unicorn with the specified number of *horns*.
def initialize(@horns = 1)
  raise "Not a unicorn" if @horns != 1
end
```

* Code blocks that have Crystal code can be surrounded with triple backticks or indented with four spaces.

``````crystal
# ```
# unicorn = Unicorn.new
# unicorn.speak
# ```
``````

or

```crystal
#     unicorn = Unicorn.new
#     unicorn.speak
```

* Text blocks, for example to show program output, must be surrounded with triple backticks followed by the "text" keyword.

``````crystal
# ```text
# "I'm a unicorn"
# ```
``````

* To automatically link to other types, enclose them with single backticks.

```crystal
# the `Legendary` module
```

* To automatically link to methods of the currently documented type, use a hash like `#horns` or `#index(char)`, and enclose it with single backticks.

* To automatically link to methods in other types, do `OtherType#method(arg1, arg2)` or just `OtherType#method`, and enclose it with single backticks.

For example:

```crystal
# Check the number of horns with `#horns`.
# See what a unicorn would say with `Unicorn#speak`.
```

* To show the value of an expression inside code blocks, use `#=>`.

```crystal
1 + 2             # => 3
Unicorn.new.speak # => "I'm a unicorn"
```

* Use `ditto` to use the same comment as in the previous declaration.

```crystal
# ditto
def number_of_horns
  horns
end
```

* Use `:nodoc:` to hide public declarations from the generated documentation. Private and protected methods are always hidden.

```crystal
class Unicorn
  # :nodoc:
  class Helper
  end
end
```

### Use Crystal's code formatter

Crystal's built-in code formatter can be used not just to format your code,
but also to format code samples included in documentation blocks.

This is done automatically when `crystal tool format` is invoked, which
will automatically format all `.cr` files in current directory.

To format a single file:

```
$ crystal tool format file.cr
```

To format all `.cr` files within a directory:

```
$ crystal tool format src/
```

Use this tool to unify code styles and to submit documentation improvements to
Crystal itself.

The formatter is also fast, so very little time is lost if you format the
entire project instead of a single file.

### A Complete Example

``````crystal
# A unicorn is a **legendary animal** (see the `Legendary` module) that has been
# described since antiquity as a beast with a large, spiraling horn projecting
# from its forhead.
#
# To create a unicorn:
#
# ```
# unicorn = Unicorn.new
# unicorn.speak
# ```
#
# The above produces:
#
# ```text
# "I'm a unicorn"
# ```
#
# Check the number of horns with `#horns`.
class Unicorn
  include Legendary

  # Creates a unicorn with the specified number of *horns*.
  def initialize(@horns = 1)
    raise "Not a unicorn" if @horns != 1
  end

  # Returns the number of horns this unicorn has
  #
  # ```
  # Unicorn.new.horns # => 1
  # ```
  def horns
    @horns
  end

  # ditto
  def number_of_horns
    horns
  end

  # Makes the unicorn speak to STDOUT
  def speak
    puts "I'm a unicorn"
  end

  # :nodoc:
  class Helper
  end
end
``````

### Generate Documentation

To generate documentation for a project, invoke `crystal doc`. This will create a `doc` directory, with a `doc/index.html` entry point. All files inside the root `src` directory will be considered.
