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
# You can also pass an RGB color to `colorize`:
# ```
# "foo".colorize(Colorize::ColorRGB.new(0, 255, 255)) # => "foo" in aqua
# ```
#
# Or an 8-bit color:
# ```
# "foo".colorize(Colorize::Color256.new(208)) # => "foo" in orange
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
# "foo".colorize(:red).toggle(false)              # => "foo" without color
# "foo".colorize(:red).toggle(false).toggle(true) # => "foo" in red
# ```
#
# The color `:default` will just leave the object as it is (but it's an `Colorize::Object(String)` then).
# That's handy in for example conditions:
# ```
# "foo".colorize(some_bool ? :green : :default)
# ```
#
# Available colors are:
# ```
# :default
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

  # Makes `Colorize.enabled` `true` if and only if both of `STDOUT.tty?` and `STDERR.tty?` are `true`.
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

module Colorize
  alias Color = ColorANSI | Color256 | ColorRGB

  enum ColorANSI
    Default      = 39
    Black        = 30
    Red          = 31
    Green        = 32
    Yellow       = 33
    Blue         = 34
    Magenta      = 35
    Cyan         = 36
    LightGray    = 37
    DarkGray     = 90
    LightRed     = 91
    LightGreen   = 92
    LightYellow  = 93
    LightBlue    = 94
    LightMagenta = 95
    LightCyan    = 96
    White        = 97

    def fore(io : IO) : Nil
      to_i.to_s io
    end

    def back(io : IO) : Nil
      (to_i + 10).to_s io
    end
  end

  record Color256,
    value : UInt8 do
    def fore(io : IO) : Nil
      io << "38;5;"
      value.to_s io
    end

    def back(io : IO) : Nil
      io << "48;5;"
      value.to_s io
    end
  end

  record ColorRGB,
    red : UInt8,
    green : UInt8,
    blue : UInt8 do
    def fore(io : IO) : Nil
      io << "38;2;"
      {red, green, blue}.join(';', io, &.to_s io)
    end

    def back(io : IO) : Nil
      io << "48;2;"
      {red, green, blue}.join(';', io, &.to_s io)
    end
  end
end

struct Colorize::Object(T)
  private MODE_DEFAULT   = '0'
  private MODE_BOLD      = '1'
  private MODE_BRIGHT    = '1'
  private MODE_DIM       = '2'
  private MODE_UNDERLINE = '4'
  private MODE_BLINK     = '5'
  private MODE_REVERSE   = '7'
  private MODE_HIDDEN    = '8'

  private MODE_BOLD_FLAG      =  1
  private MODE_BRIGHT_FLAG    =  1
  private MODE_DIM_FLAG       =  2
  private MODE_UNDERLINE_FLAG =  4
  private MODE_BLINK_FLAG     =  8
  private MODE_REVERSE_FLAG   = 16
  private MODE_HIDDEN_FLAG    = 32

  private COLORS = %w(default black red green yellow blue magenta cyan light_gray dark_gray light_red light_green light_yellow light_blue light_magenta light_cyan white)
  private MODES  = %w(bold bright dim underline blink reverse hidden)

  @fore : Color
  @back : Color

  def initialize(@object : T)
    @fore = ColorANSI::Default
    @back = ColorANSI::Default
    @mode = 0
    @enabled = Colorize.enabled?
  end

  {% for name in COLORS %}
    def {{name.id}}
      @fore = ColorANSI::{{name.camelcase.id}}
      self
    end

    def on_{{name.id}}
      @back = ColorANSI::{{name.camelcase.id}}
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
        @fore = ColorANSI::{{name.camelcase.id}}
        return self
      end
    {% end %}

    raise ArgumentError.new "Unknown color: #{color}"
  end

  def fore(@fore : Color)
    self
  end

  def back(color : Symbol)
    {% for name in COLORS %}
      if color == :{{name.id}}
        @back = ColorANSI::{{name.camelcase.id}}
        return self
      end
    {% end %}

    raise ArgumentError.new "Unknown color: #{color}"
  end

  def back(@back : Color)
    self
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

  def to_s(io : IO) : Nil
    surround(io) do
      io << @object
    end
  end

  def inspect(io : IO) : Nil
    surround(io) do
      @object.inspect(io)
    end
  end

  def surround(io = STDOUT)
    return yield io unless @enabled

    Object.surround(io, to_named_tuple) do |io|
      yield io
    end
  end

  private def to_named_tuple
    {
      fore: @fore,
      back: @back,
      mode: @mode,
    }
  end

  @@last_color = {
    fore: ColorANSI::Default.as(Color),
    back: ColorANSI::Default.as(Color),
    mode: 0,
  }

  protected def self.surround(io, color)
    last_color = @@last_color
    must_append_end = append_start(io, color)
    @@last_color = color

    begin
      yield io
    ensure
      append_start(io, last_color) if must_append_end
      @@last_color = last_color
    end
  end

  private def self.append_start(io, color)
    last_color_is_default =
      @@last_color[:fore] == ColorANSI::Default &&
        @@last_color[:back] == ColorANSI::Default &&
        @@last_color[:mode] == 0

    fore = color[:fore]
    back = color[:back]
    mode = color[:mode]

    fore_is_default = fore == ColorANSI::Default
    back_is_default = back == ColorANSI::Default
    mode_is_default = mode == 0

    if fore_is_default && back_is_default && mode_is_default && last_color_is_default || @@last_color == color
      false
    else
      io << "\e["

      printed = false

      unless last_color_is_default
        io << MODE_DEFAULT
        printed = true
      end

      unless fore_is_default
        io << ';' if printed
        fore.fore io
        printed = true
      end

      unless back_is_default
        io << ';' if printed
        back.back io
        printed = true
      end

      unless mode_is_default
        # Can't reuse MODES constant because it has bold/bright duplicated
        {% for name in %w(bold dim underline blink reverse hidden) %}
          if mode.bits_set? MODE_{{name.upcase.id}}_FLAG
            io << ';' if printed
            io << MODE_{{name.upcase.id}}
            printed = true
          end
        {% end %}
      end

      io << 'm'

      true
    end
  end
end
