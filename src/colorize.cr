require "colorize/*"

# With `Colorize` you can change the fore- and background colors and text
# decorations when rendering text on terminals supporting ANSI escape codes.
#
# It adds the `colorize` method to `Object` and thus all classes as its main
# interface, which calls `to_s` and surrounds it with the necessary escape
# codes when it comes to obtaining a string representation of the object.
#
# Or you can use `#with_color` global method, which returns `Style` object
# to represent a style (fore- and background colors and text decorations)
# on a terminal. `Style#surround` colorize given block outputs with its style.
#
# `Object` and `Style` are mixed in `StyleBuilder`,
# so we can construct a style of both classes in the same way.
#
# Theirs first argument changes the foreground color:
#
# ```
# require "colorize"
#
# "foo".colorize(:green)
# 100.colorize(:red)
# [1, 2, 3].colorize(:blue)
# with_color(:yellow)
# ```
#
# There are alternative ways to change the foreground color:
#
# ```
# "foo".colorize(fore: :green)
# with_color(fore: :green)
# "foo".colorize.fore(:green)
# with_color.fore(:green)
# "foo".colorize.green
# with_color.green
# ```
#
# To change the background color, the following methods are available:
#
# ```
# "foo".colorize(back: :green)
# with_color(back: :green)
# "foo".colorize.back(:green)
# with_color.back(:green)
# "foo".colorize.on(:green)
# with_color.on(:green)
# "foo".colorize.on_green
# with_color.on_green
# ```
#
# To specify color, you can use `String` (via `Colorize.parse_color`),
# `Int` (via `Color256.new`) and `Color` instances to specify color:
#
# ```
# with_color(fore: "red") # use `String` instead.
#
# with_color(fore: "#FDD")    # FDD means a color code, not Floppy Dick Drive.
# with_color(fore: "#FFDDDD") # It is same above.
# # These color works on only newer terminals.
#
# with_color(fore: 111)   # 111 means 256 color on terminal.
# with_color(fore: "111") # Also, use `String`.
#
# # `Color` instances.
# with_color(fore: Colorize::ColorANSI::Red)
# with_color(fore: Colorize::ColorRGB.parse "#FFDDDD")
# with_color(fore: Colorize::Color256.new 111)
# ```
#
# It's also possible to change the text decoration:
#
# ```
# "foo".colorize(mode: :underline)
# with_color(mode: :underline)
# "foo".colorize(mode: "underline")
# with_color(mode: "underline")
# "foo".colorize.mode(:underline)
# with_color.mode(:underline)
# "foo".colorize.underline
# with_color.underline
# ```
#
# The `ObjectExtension#colorize` method returns a `Colorize::Object` instance,
# which allows chaining methods together:
#
# ```
# "foo".colorize.fore(:yellow).back(:blue).mode(:underline)
# with_color.fore(:yellow).back(:blue).mode(:underline)
# ```
#
# When `::IO` class have a potential to support ANSI escape sequence, this
# `::IO` class includes `ColorizableIO` module. For example,
# `IO::FileDescriptor` includes `ColorizableIO`.
#
# `ColorizableIO` has `colorize_when` property, which value decides to output escape sequence. If this property's value is:
#
#   - `:always` (`When::Always`), it outputs escape sequence always.
#   - `:never` (`When::Never`), it doesn't output escape sequence.
#   - `:auto` (`When::Auto`), it outputs escape sequence when it is TTY.
#
# `IO::FileDescript#colorize_when`'s default value is `:auto`, so we aren't
# careful the program connects pipe or not.
#
# ```
# # If program connects to pipe (like `crystal run foo.cr | cat`), it
# # doesn't output escape sequence. But if program connects to terminal, it
# # outputs escape sequence.
# puts "foo".colorize.red
#
# # In addition, if IO class doesn't include `ColorizableIO`, it outputs
# # escape sequence as default.
# mem = IO::Memory.new
# mem << "foo".colorize.red
# mem.to_s # => "\e[31mfoo\e[0m"
#
# # Create ColorizableIO from IO object by `to_colorizable` method.
# colorizable_io = IO::Memory.new.to_colorizable
# # Default colorize policy is `Always`.
# colorizable_io.colorize_when # => Colorize::When::Always
# ```
#
# Finally, complete example is:
#
# ```
# require "colorize"
#
# # This program outpus escape sequence always
# STDOUT.colorize_when = :always
#
# # Colorize this block as bold.
# with_color.bold.surround do
#   print "Hello "
#
#   # But, colorize only "Crystal" as yellow.
#   print "Crystal".colorize.yellow
#
#   puts " World!"
# end
# ```
module Colorize
end

# Create a new `Colorize::Style` from given values.
def with_color(fore = nil, back = nil, mode = nil)
  Colorize::Style.new fore, back, mode
end

class Object
  include Colorize::ObjectExtensions
end

module IO
  include Colorize::IOExtension
end
