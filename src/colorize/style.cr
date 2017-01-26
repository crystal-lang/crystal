require "./io"

# `Style` represents a colorize style on the terminal.
#
# ```
# # Create a new style by the constructor.
# style = Colorize::Style.new(fore: :red, back: :blue, mode: :underline)
#
# # Or, we can use `StyleBuilder`'s methods for construction.
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
  include StyleBuilder

  # Creates a new instance with *fore*, *back* and *mode*.
  def initialize(fore = nil, back = nil, mode = nil)
    style fore, back, mode
  end

  # Output escape sequence of this style.
  def to_s(io)
    IO.new(io).colorize_write style, reset: false
  end

  # Get escape sequence of this style.
  #
  # ```
  # Colorize::Style.new(:red).to_s # => "\e[31m"
  # ```
  def to_s
    String.build do |io|
      escape_sequence io
    end
  end

  # Colorize the content in the block with this style.
  #
  # It is short hand for `IO#surround`.
  def surround(io = STDOUT)
    IO.new(io).surround(self) { |io| with io yield io }
  end

  # DEPRECATED: use `#surround`. This method will be removed after 0.21.0.
  def push(io = STDOUT)
    {{ puts "`Colorize::Style#push` is deprecated and will be removed after 0.21.0, use `Colorize::Style#surround` instead".id }}
    surround(io) { |io| with io yield io }
  end

  # :nodoc:
  def_equals_and_hash fore, back, mode
end
