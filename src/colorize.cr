# With `Colorize` you can change the fore- and background colors and text decorations when rendering text
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
# require "colorize"
#
# "foo".colorize.fore(:green)
# "foo".colorize.green
# ```
#
# To change the background color, the following methods are available:
# ```
# require "colorize"
#
# "foo".colorize.back(:green)
# "foo".colorize.on(:green)
# "foo".colorize.on_green
# ```
#
# You can also pass an RGB color to `colorize`:
# ```
# require "colorize"
#
# "foo".colorize(0, 255, 255) # => "foo" in aqua
#
# # This is the same as:
#
# "foo".colorize(Colorize::ColorRGB.new(0, 255, 255)) # => "foo" in aqua
# ```
#
# Or an 8-bit color:
# ```
# require "colorize"
#
# "foo".colorize(Colorize::Color256.new(208)) # => "foo" in orange
# ```
#
# It's also possible to change the text decoration:
# ```
# require "colorize"
#
# "foo".colorize.mode(:underline)
# "foo".colorize.underline
# ```
#
# The `colorize` method returns a `Colorize::Object` instance,
# which allows chaining methods together:
# ```
# require "colorize"
#
# "foo".colorize.fore(:yellow).back(:blue).mode(:underline)
# ```
#
# With the `toggle` method you can temporarily disable adding the escape codes.
# Settings of the instance are preserved however and can be turned back on later:
# ```
# require "colorize"
#
# "foo".colorize(:red).toggle(false)              # => "foo" without color
# "foo".colorize(:red).toggle(false).toggle(true) # => "foo" in red
# ```
#
# The color `:default` leaves the object's representation as it is but the object is a `Colorize::Object` then
# which is handy in conditions such as:
# ```
# require "colorize"
#
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
  # require "colorize"
  #
  # Colorize.enabled = true
  # "hello".colorize.red.to_s # => "hello" in red
  #
  # Colorize.enabled = false
  # "hello".colorize.red.to_s # => "hello"
  # ```
  #
  # NOTE: This is by default disabled on non-TTY devices as they most likely do not support ANSI escape codes.
  class_property? enabled : Bool = STDOUT.tty? && STDERR.tty?

  # Resets the color of the object to the default.
  def self.reset(io = STDOUT)
    io << "\e[0m" if enabled?
  end
end

def with_color
  "".colorize
end

def with_color(color : Colorize::Color)
  "".colorize(color)
end

module Colorize::ObjectExtensions
  # Turns `self` into a `Colorize::Object`.
  def colorize
    Colorize::Object.new(self)
  end

  # Turns `self` into a `Colorize::Object` and colors it.
  def colorize(fore : Color)
    Colorize::Object.new(self).fore(fore)
  end

  # Turns `self` into a `Colorize::Object` and colors it with an RGB color.
  def colorize(r : UInt8, g : UInt8, b : UInt8)
    Colorize::Object.new(self).fore(Colorize::ColorRGB.new(r, g, b))
  end
end

class Object
  include Colorize::ObjectExtensions
end

module Colorize
  alias Color = ColorANSI | Color256 | ColorRGB

  # One color of a fixed set of colors.
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

  # An 8-bit color.
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

  # An RGB color.
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

  # A text decoration.
  #
  # Note that not all decorations are supported in all terminals.
  # When a decoration is not supported, the text won't have any decoration.
  @[Flags]
  enum Mode
    # Makes the text bold.
    Bold = 1
    # Makes the text color bright.
    Bright = 1
    # Dims the text color, the opposite of `Bold` and `Bright`.
    Dim
    # Underlines the text.
    Underline
    # Makes the text blink slowly.
    Blink
    # Swaps the foreground and background colors.
    Reverse
    # Makes the text invisible.
    Hidden
  end
end

# A colorize object colors and decorations can be applied to.
struct Colorize::Object(T)
  private MODE_NONE      = '0'
  private MODE_BOLD      = '1'
  private MODE_BRIGHT    = '1'
  private MODE_DIM       = '2'
  private MODE_UNDERLINE = '4'
  private MODE_BLINK     = '5'
  private MODE_REVERSE   = '7'
  private MODE_HIDDEN    = '8'

  private COLORS = %w(default black red green yellow blue magenta cyan light_gray dark_gray light_red light_green light_yellow light_blue light_magenta light_cyan white)
  private MODES  = %w(bold bright dim underline blink reverse hidden)

  def initialize(@object : T)
    @fore = ColorANSI::Default
    @back = ColorANSI::Default
    @mode = Mode::None
    @enabled = Colorize.enabled?
  end

  {% for color in COLORS %}
    def {{color.id}}
      @fore = ColorANSI::{{color.camelcase.id}}
      self
    end

    def on_{{color.id}}
      @back = ColorANSI::{{color.camelcase.id}}
      self
    end
  {% end %}

  {% for mode in MODES %}
    def {{mode.id}}
      @mode |= Mode::{{mode.capitalize.id}}
      self
    end
  {% end %}

  # Sets the foreground color of the object to *color*.
  def fore(color : Color)
    @fore = color
    self
  end

  # Sets the background color of the object to *color*.
  def back(color : Color)
    @back = color
    self
  end

  # Adds *mode* to the text's decorations.
  def mode(mode : Mode)
    @mode |= mode
    self
  end

  # Enables or disables colors and text decoration on this object.
  def toggle(flag)
    @enabled = !!flag
    self
  end

  # Appends this object colored and with text decoration to *io*.
  def to_s(io : IO) : Nil
    surround(io) do
      io << @object
    end
  end

  # Inspects this object and makes the ANSI escape codes visible.
  def inspect(io : IO) : Nil
    internal_io = IO::Memory.new
    (surround(internal_io) do
      @object.to_s(internal_io)
    end)
    io << internal_io.to_s.inspect
  end

  # Surrounds *io* by the ANSI escape codes and let's you build colored strings:
  #
  # ```
  # io = IO::Memory.new
  #
  # with_color.red.surround(io) do
  #   io << "colorful"
  #   with_color.green.bold.surround(io) do
  #     io << " hello "
  #   end
  #   with_color.blue.surround(io) do
  #     io << "world"
  #   end
  #   io << " string"
  # end
  #
  # io.to_s # => "colorful hello world string"
  # # Where "colorful" is red, "hello" green, "world" blue and " string" red again
  # ```
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
    mode: Mode::None,
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
        @@last_color[:mode] == Mode::None

    fore = color[:fore]
    back = color[:back]
    mode = color[:mode]

    fore_is_default = fore == ColorANSI::Default
    back_is_default = back == ColorANSI::Default
    no_mode = mode == Mode::None

    if @@last_color == color || fore_is_default && back_is_default && no_mode && last_color_is_default
      false
    else
      io << "\e["

      printed = false

      unless last_color_is_default
        io << MODE_NONE
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

      unless no_mode
        # Can't reuse MODES constant because it has bold/bright duplicated
        {% for mode in %w(bold dim underline blink reverse hidden) %}
          if mode.includes? Mode::{{mode.capitalize.id}}
            io << ';' if printed
            io << MODE_{{mode.upcase.id}}
            printed = true
          end
        {% end %}
      end

      io << 'm'

      true
    end
  end
end
