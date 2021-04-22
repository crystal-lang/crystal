# With `Colorize` you can change the fore- and background colors and text decorations when rendering text
# on terminals supporting ANSI escape codes. It adds the `colorize` method to `Object` and thus all classes
# as its main interface, which calls `to_s` and surrounds it with the necessary escape codes
# when it comes to obtaining a string representation of the object.
#
# Its first argument changes the foreground color:
#
# ```
# require "colorize"
#
# "foo".colorize(:green)
# 100.colorize(:red)
# [1, 2, 3].colorize(:blue)
# ```
#
# There are alternative ways to change the foreground color:
#
# ```
# require "colorize"
#
# "foo".colorize.fore(:green)
# "foo".colorize.green
# ```
#
# To change the background color, the following methods are available:
#
# ```
# require "colorize"
#
# "foo".colorize.back(:green)
# "foo".colorize.on(:green)
# "foo".colorize.on_green
# ```
#
# You can also pass an RGB color to `colorize`:
#
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
#
# ```
# require "colorize"
#
# "foo".colorize(Colorize::Color256.new(208)) # => "foo" in orange
# ```
#
# It's also possible to change the text decoration:
#
# ```
# require "colorize"
#
# "foo".colorize.mode(:underline)
# "foo".colorize.underline
# ```
#
# The `colorize` method returns a `Colorize::Object` instance,
# which allows chaining methods together:
#
# ```
# require "colorize"
#
# "foo".colorize.fore(:yellow).back(:blue).mode(:underline)
# ```
#
# With the `toggle` method you can temporarily disable adding the escape codes.
# Settings of the instance are preserved however and can be turned back on later:
#
# ```
# require "colorize"
#
# "foo".colorize(:red).toggle(false)              # => "foo" without color
# "foo".colorize(:red).toggle(false).toggle(true) # => "foo" in red
# ```
#
# The color `:default` leaves the object's representation as it is but the object is a `Colorize::Object` then
# which is handy in conditions such as:
#
# ```
# require "colorize"
#
# "foo".colorize(Random::DEFAULT.next_bool ? :green : :default)
# ```
#
# See `Colorize::ColorANSI` and `Colorize::Mode` for all available colors and text decorations.
module Colorize
  # Objects will only be colored if this is `true`.
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
  # NOTE: This is by default disabled on non-TTY devices because they likely don't support ANSI escape codes.
  # This is also be disabled if the environment variable `TERM` is "dumb".
  class_property? enabled : Bool = STDOUT.tty? && STDERR.tty? && ENV["TERM"]? != "dumb"

  # Resets the color and text decoration of the *io*.
  #
  # ```
  # with_color.green.surround(io) do
  #   io << "green"
  #   Colorize.reset
  #   io << " default"
  # end
  # ```
  def self.reset(io = STDOUT)
    io << "\e[0m" if enabled?
  end

  # Helper method to use colorize with `IO`.
  #
  # ```
  # io = IO::Memory.new
  # io << "not-green"
  # Colorize.with.green.bold.surround(io) do
  #   io << "green and bold if Colorize.enabled"
  # end
  # ```
  def self.with
    "".colorize
  end
end

module Colorize::ObjectExtensions
  # Turns `self` into a `Colorize::Object`.
  def colorize
    Colorize::Object.new(self)
  end

  # Turns `self` into a `Colorize::Object` and colors it with a color.
  def colorize(fore : Color)
    Colorize::Object.new(self).fore(fore)
  end

  # Turns `self` into a `Colorize::Object` and colors it with an RGB color.
  def colorize(red : UInt8, green : UInt8, blue : UInt8)
    colorize(Colorize::ColorRGB.new(red, green, blue))
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
      io << red << ";"
      io << green << ";"
      io << blue
    end

    def back(io : IO) : Nil
      io << "48;2;"
      io << red << ";"
      io << green << ";"
      io << blue
    end
  end

  # A text decoration.
  #
  # Note that not all text decorations are supported in all terminals.
  # When a text decoration is not supported, it will leave the text unaffected.
  @[Flags]
  enum Mode
    # Makes the text bold.
    Bold = 1
    # Makes the text color bright.
    @[Deprecated("Please use `bold` instead.")]
    Bright = 1
    # Dims the text color.
    Dim
    # Underlines the text.
    Underline
    # Makes the text blink slowly.
    Blink
    # Swaps the foreground and background colors of the text.
    Reverse
    # Makes the text invisible.
    Hidden
  end
end

# A colorized object. Colors and text decorations can be modified.
struct Colorize::Object(T)
  private MODE_NONE      = '0'
  private MODE_BOLD      = '1'
  private MODE_BRIGHT    = '1' # TODO: Remove this in the future
  private MODE_DIM       = '2'
  private MODE_UNDERLINE = '4'
  private MODE_BLINK     = '5'
  private MODE_REVERSE   = '7'
  private MODE_HIDDEN    = '8'

  def initialize(@object : T)
    @fore = ColorANSI::Default
    @back = ColorANSI::Default
    @mode = Mode::None
    @enabled = Colorize.enabled?
  end

  {% for color in ColorANSI.constants.reject { |constant| constant == "All" || constant == "None" } %}
    def {{color.underscore.id}}
      @fore = ColorANSI::{{color.id}}
      self
    end

    def on_{{color.underscore.id}}
      @back = ColorANSI::{{color.id}}
      self
    end
  {% end %}

  def on(color : Color)
    back color
  end

  {% for mode in Mode.constants.reject { |constant| constant == "All" || constant == "None" } %}
    def {{mode.underscore.id}}
      @mode |= Mode::{{mode.id}}
      self
    end
  {% end %}

  @[Deprecated("Please use `bold` instead.")]
  def bright
    @mode |= Mode::Bold
    self
  end

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

  @@warning_printed = false

  # Adds *mode* to the text's decorations.
  def mode(mode : Mode)
    # TODO: Remove this in the future
    if mode == Mode::Bright
      puts "Warning: The text decoration `bright` is deprecated. Please use `bold` instead.".colorize(:light_yellow) unless @@warning_printed
      @@warning_printed = true
    end

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
    surround(internal_io) do
      @object.to_s(internal_io)
    end
    io << internal_io.to_s.inspect
  end

  # Surrounds *io* by the ANSI escape codes and lets you build colored strings:
  #
  # ```
  # require "colorize"
  #
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

  # :nodoc:
  def to_named_tuple
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

  # :nodoc:
  def self.append_start(io, color)
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
        # TODO: replace this by
        # {% for mode in Mode.constants.reject { |constant| constant == "All" || constant == "None" } %}
        # when bright gets removed
        {% for mode in %w(Bold Dim Underline Blink Reverse Hidden) %}
          if mode.includes? Mode::{{mode.id}}
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
