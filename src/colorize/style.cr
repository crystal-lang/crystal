require "./builder"
require "./io"

# `Style` represents a colorize style on the terminal.
#
# ```
# # Create a new style by the constructor.
# style = Colorize::Style.new(:red, :blue, :underline)
#
# # Or, we can use `Builder`'s methods for construction.
# style = Colorize::Style.new
#                        .fore(:red)
#                        .back(:blue)
#                        .mode(:underline)
#
# # Get an escape sequence to colorize with this style.
# style.to_s # => "\e[31;44;4m"
#
# # Colorize the content in a block with this style.
# style.surround do
#   puts "Hello, World!"
# end
# ```
struct Colorize::Style
  include Builder

  # Creates a new instance with *fore*, *back* and *mode*.
  #
  # All parameter is passed to each setter methods.
  def initialize(fore = nil, back = nil, mode = nil, when policy = nil)
    fore fore
    back back
    mode mode
    self.when policy
  end

  # Get an escape sequence to colorize with this style.
  #
  # NOTE: This method does not check given *io* is TTY when `#policy` is `When::Auto`.
  def to_s(io)
    Colorize.write_style self, io
  end

  # Colorize the content in the block with this style.
  #
  # It outputs an escape sequence, then invokes the block. After all, it outputs reset escape sequence if needed.
  #
  # This method has a stack internally, so it keeps colorizing if nested.
  def surround(io = STDOUT)
    Colorize.surround(self, io) { |io| yield io }
  end

  # DEPRECATED: use `#surround`. This method will be removed after 0.21.0.
  def push(io = STDOUT)
    {{ puts "`Colorize::Style#push` is deprecated and will be removed after 0.21.0, use `Colorize::Style#surround` instead".id }}
    surround(io) { |io| yield io }
  end

  def_equals_and_hash fore, back, mode, :when
end
