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
  # If this value is `true`, `Colorize::Object` is enabled by default.
  # But if this value is `false`, `Colorize::Object` is disabled.
  #
  # The default value is `true`.
  #
  # ```
  # Colorize.enabled = true
  # "hello".colorize.red.to_s # => "\e[31mhello\e[0m"
  #
  # Colorize.enabled = false
  # "hello".colorize.red.to_s # => "hello"
  # ```
  class_property? enabled : Bool = true

  # Make `Colorize.enabled` `true` if and only if both of `STDOUT.tty?` and `STDERR.tty?` are `true`.
  def self.on_tty_only!
    self.enabled = STDOUT.tty? && STDERR.tty?
  end

  def self.reset(io = STDOUT)
    io << "\e[0m" if enabled?
  end
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

struct Colorize::Object(T)
  private FORE_DEFAULT       = "39"
  private FORE_BLACK         = "30"
  private FORE_RED           = "31"
  private FORE_GREEN         = "32"
  private FORE_YELLOW        = "33"
  private FORE_BLUE          = "34"
  private FORE_MAGENTA       = "35"
  private FORE_CYAN          = "36"
  private FORE_LIGHT_GRAY    = "37"
  private FORE_DARK_GRAY     = "90"
  private FORE_LIGHT_RED     = "91"
  private FORE_LIGHT_GREEN   = "92"
  private FORE_LIGHT_YELLOW  = "93"
  private FORE_LIGHT_BLUE    = "94"
  private FORE_LIGHT_MAGENTA = "95"
  private FORE_LIGHT_CYAN    = "96"
  private FORE_WHITE         = "97"

  private BACK_DEFAULT       = "49"
  private BACK_BLACK         = "40"
  private BACK_RED           = "41"
  private BACK_GREEN         = "42"
  private BACK_YELLOW        = "43"
  private BACK_BLUE          = "44"
  private BACK_MAGENTA       = "45"
  private BACK_CYAN          = "46"
  private BACK_LIGHT_GRAY    = "47"
  private BACK_DARK_GRAY     = "100"
  private BACK_LIGHT_RED     = "101"
  private BACK_LIGHT_GREEN   = "102"
  private BACK_LIGHT_YELLOW  = "103"
  private BACK_LIGHT_BLUE    = "104"
  private BACK_LIGHT_MAGENTA = "105"
  private BACK_LIGHT_CYAN    = "106"
  private BACK_WHITE         = "107"

  private MODE_DEFAULT   = "0"
  private MODE_BOLD      = "1"
  private MODE_BRIGHT    = "1"
  private MODE_DIM       = "2"
  private MODE_UNDERLINE = "4"
  private MODE_BLINK     = "5"
  private MODE_REVERSE   = "7"
  private MODE_HIDDEN    = "8"

  private MODE_BOLD_FLAG      =  1
  private MODE_BRIGHT_FLAG    =  1
  private MODE_DIM_FLAG       =  2
  private MODE_UNDERLINE_FLAG =  4
  private MODE_BLINK_FLAG     =  8
  private MODE_REVERSE_FLAG   = 16
  private MODE_HIDDEN_FLAG    = 32

  private COLORS = %w(black red green yellow blue magenta cyan light_gray dark_gray light_red light_green light_yellow light_blue light_magenta light_cyan white)
  private MODES  = %w(bold bright dim underline blink reverse hidden)

  def initialize(@object : T)
    @fore = FORE_DEFAULT
    @back = BACK_DEFAULT
    @mode = 0
    @enabled = Colorize.enabled?
  end

  {% for name in COLORS %}
    def {{name.id}}
      @fore = FORE_{{name.upcase.id}}
      self
    end

    def on_{{name.id}}
      @back = BACK_{{name.upcase.id}}
      self
    end
  {% end %}

  {% for name in MODES %}
    def {{name.id}}
      @mode |= MODE_{{name.upcase.id}}_FLAG
      self
    end
  {% end %}

  def fore(color : Symbol)
    {% for name in COLORS %}
      if color == :{{name.id}}
        @fore = FORE_{{name.upcase.id}}
        return self
      end
    {% end %}

    raise ArgumentError.new "Unknown color: #{color}"
  end

  def back(color : Symbol)
    {% for name in COLORS %}
      if color == :{{name.id}}
        @back = BACK_{{name.upcase.id}}
        return self
      end
    {% end %}

    raise ArgumentError.new "Unknown color: #{color}"
  end

  def mode(mode : Symbol)
    {% for name in MODES %}
      if mode == :{{name.id}}
        @mode |= MODE_{{name.upcase.id}}_FLAG
        return self
      end
    {% end %}

    raise ArgumentError.new "Unknown mode: #{mode}"
  end

  def on(color : Symbol)
    back color
  end

  def toggle(flag)
    @enabled = !!flag
    self
  end

  def to_s(io)
    surround(io) do
      io << @object
    end
  end

  def inspect(io)
    surround(io) do
      @object.inspect(io)
    end
  end

  def surround(io = STDOUT)
    must_append_end = append_start(io)
    yield io
    append_end(io) if must_append_end
  end

  STACK = [] of Colorize::Object(String)

  def push(io = STDOUT)
    last_color = STACK.last?

    append_start(io, !!last_color)

    STACK.push self
    yield io
    STACK.pop

    if last_color
      last_color.append_start(io, true)
    else
      append_end(io)
    end
  end

  protected def append_start(io, reset = false)
    return false unless @enabled

    fore_is_default = @fore == FORE_DEFAULT
    back_is_default = @back == BACK_DEFAULT
    mode_is_default = @mode == 0

    if fore_is_default && back_is_default && mode_is_default && !reset
      false
    else
      io << "\e["

      printed = false

      if reset
        io << MODE_DEFAULT
        printed = true
      end

      unless fore_is_default
        io << ";" if printed
        io << @fore
        printed = true
      end

      unless back_is_default
        io << ";" if printed
        io << @back
        printed = true
      end

      unless mode_is_default
        # Can't reuse MODES constant because it has bold/bright duplicated
        {% for name in %w(bold dim underline blink reverse hidden) %}
          if (@mode & MODE_{{name.upcase.id}}_FLAG) != 0
            io << ";" if printed
            io << MODE_{{name.upcase.id}}
            printed = true
          end
        {% end %}
      end

      io << "m"

      true
    end
  end

  protected def append_end(io)
    Colorize.reset(io)
  end
end
