# Documenting code

Crystal documentation comments use a subset of [Markdown](https://daringfireball.net/projects/markdown/). For example:

`````crystal
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
  # Unicorn.new.horns #=> 1
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
`````

Some details:
* Use the third person: "Returns the number of horns" instead of "Return the number of horns".
* Parameter names should be *italicized* (surrounded with single asterisks or underscores).
* Code blocks that have Crystal code can be surrounded with triple backticks or indented with four spaces
* Text blocks, for example to show program output, must be surrounded with triple backticks followed by the "text" word.
* To automatically link to other types, enclose them with single backticks.
* To automaitcally link to methods of the currently documented type, use a hash, like `#horns` or `#index(char)`.
* To automatically link to methods in other types, do `OtherType#method(arg1, arg2)` or just `OtherType#method`.
* To show expression values inside code blocks, use `#=>`, as in `1 + 2 #=> 3`.
* Use "ditto" to use the same comment as in the previous declaration
* Use ":nodoc:" to hide public declarations from the generated documentation. Private and protected methods are always hidden.

To generate documentation for a project, invoke `crystal doc`. This will create a `doc` directory, with a `doc/index.html` entry point. All files inside the root `src` directory will be considered.
