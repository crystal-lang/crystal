# With Colorize you can change the fore- and background colors and text decorations when rendering text
# on terminals supporting ANSI escape codes. It adds the `colorize` method to `Object` and thus all classes
# as its main interface, which calls `to_s` and surrounds it with the necessary escape codes
# when it comes to obtaining a string representation of the object.
#
# Its first argument changes the foreground color:
# ```
# require "colorize"
#
# "foo".colorize(:green)
# 100.colorize(:red)
# [1, 2, 3].colorize(:blue)
# ```
#
# There are alternative ways to change the foreground color:
# ```
# "foo".colorize.fore(:green)
# "foo".colorize.green
# ```
#
# To change the background color, the following methods are available:
# ```
# "foo".colorize.back(:green)
# "foo".colorize.on(:green)
# "foo".colorize.on_green
# ```
#
# It's also possible to change the text decoration:
# ```
# "foo".colorize.mode(:underline)
# "foo".colorize.underline
# ```
#
# The `colorize` method returns a `Colorize::Object` instance,
# which allows chaining methods together:
# ```
# "foo".colorize.fore(:yellow).back(:blue).mode(:underline)
# ```
#
# With the `toggle` method you can temporarily disable adding the escape codes.
# Settings of the instance are preserved however and can be turned back on later:
# ```
# "foo".colorize(:red).toggle(false)
# # => "foo" without color
# "foo".colorize(:red).toggle(false).toggle(true)
# # => "foo" in red
# ```
#
# Available colors are:
# ```
# :black
# :red
# :green
# :yellow
# :blue
# :magenta
# :cyan
# :light_gray
# :dark_gray
# :light_red
# :light_green
# :light_yellow
# :light_blue
# :light_magenta
# :light_cyan
# :white
# ```
#
# Available text decorations are:
# ```
# :bold
# :bright
# :dim
# :underline
# :blink
# :reverse
# :hidden
# ```
module Colorize
end

def with_color
  "".colorize
end

def with_color(color : Symbol)
  "".colorize(color)
end

module Colorize::ObjectExtensions
  def colorize
    Colorize::Object.new(self)
  end

  def colorize(fore)
    Colorize::Object.new(self).fore(fore)
  end
end

class Object
  include Colorize::ObjectExtensions
end
