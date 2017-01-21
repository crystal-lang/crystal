require "colorize/*"

# With `Colorize` you can change the fore- and background colors and text decorations when rendering text
# on terminals supporting ANSI escape codes.
#
# It adds the `colorize` method to `Object` and thus all classes as its main
# interface, which calls `to_s` and surrounds it with the necessary escape
# codes when it comes to obtaining a string representation of the object.
#
# Or you can use `#with_color` global method, which returns `Style` object
# to represent a style (fore- and background colors and text decorations) on a terminal. `Style#surround` colorize given block outputs with its style.
#
# `Object` and `Style` are mixed in `Builder`, so we can construct a style of both classes in the same way.
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
# By the way, you can use `String` (via `.parse_color), `Int` (via `Color256.new`) and `Color` instances to specify color:
#
# ```
# with_color(fore: "red")     # use `String` instead.
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
# It outputs escape sequences only if target `IO` is TTY.
# You can change this behavior with `always`, `never`, `auto` and `when` methods:
#
# ```
# # Output colorized `"foo"` if `STDOUT` is TTY (default)
# puts "foo".colorize(fore: :red)
# puts "foo".colorize(fore: :red).auto # explicit
# with_color(fore: :red).surround { puts "foo" }
# with_color(fore: :red).auto.surround { puts "foo" } # explicit
#
# # Output colorized `"foo"` even if `STDOUT` is not TTY.
# puts "foo".colorize(fore: :red).always
# with_color(fore: :red).always.surround { puts "foo" }
#
# # Output not colorized `"foo"` even if `STDOUT` is TTY.
# puts "foo".colorize(fore: :red).never
# with_color(fore: :red).never.surround { puts "foo" }
#
# # Alternative ways:
# puts "foo".colorize(fore: :red, when: :always)
# with_color(fore: :red, when: :always).surround { puts "foo" }
# puts "foo".colorize(fore: :red).when(:never)
# with_color(fore: :red).when(:always).surround { puts "foo" }
#
# # Last specified policy is only available.
# puts "foo".colorize.always.auto.never # output no escape sequence.
# with_color(fore: :red).never.auto.always.surround { puts "foo" } # output no escape sequence.
# ```
module Colorize
  module ObjectExtensions
    def colorize(fore = nil, back = nil, mode = nil, when policy = nil)
      Colorize::Object.new(self)
                      .fore(fore)
                      .back(back)
                      .mode(mode)
                      .when(policy)
    end
  end
end

def with_color(fore = nil, back = nil, mode = nil, when policy = nil)
  Colorize::Style.new fore, back, mode, policy
end

class Object
  include Colorize::ObjectExtensions
end
