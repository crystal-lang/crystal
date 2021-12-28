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
# The color `:default` will just leave the object as it is (but it's an `Colorize::Object(String)` then).
# That's handy in for example conditions:
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
# See `Colorize::Mode` for available text decorations.
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
  # "hello".colorize.red.to_s # => "\e[31mhello\e[0m"
  #
  # Colorize.enabled = false
  # "hello".colorize.red.to_s # => "hello"
  # ```
  class_property? enabled : Bool = true

  # Makes `Colorize.enabled` `true` if and only if both of `STDOUT.tty?`
  # and `STDERR.tty?` are `true` and the tty is not considered a dumb terminal.
  # This is determined by the environment variable called `TERM`.
  # If `TERM=dumb`, color won't be enabled.
  def self.on_tty_only!
    self.enabled = STDOUT.tty? && STDERR.tty? && ENV["TERM"]? != "dumb"
  end

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
  def self.with : Colorize::Object(String)
    "".colorize
  end
end

module Colorize::ObjectExtensions
  def colorize : Colorize::Object
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

    def code : Char
      case self
      when .none?           then '0'
      when .bold?, .bright? then '1'
      when .dim?            then '2'
      when .underline?      then '4'
      when .blink?          then '5'
      when .reverse?        then '7'
      when .hidden?         then '8'
      else
        raise "unreachable"
      end
    end
  end
end

struct Colorize::Object(T)
  private COLORS = %w(default black red green yellow blue magenta cyan light_gray dark_gray light_red light_green light_yellow light_blue light_magenta light_cyan white)

  @fore : Color
  @back : Color

  def initialize(@object : T)
    @fore = ColorANSI::Default
    @back = ColorANSI::Default
    @mode = Mode::None
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

  {% for mode in Mode.constants.reject { |constant| constant == "All" || constant == "None" } %}
    # Apply text decoration `Mode::{{ mode }}`.
    def {{mode.underscore.id}}
      mode Mode::{{mode.id}}
    end
  {% end %}

  def fore(color : Symbol) : self
    {% for name in COLORS %}
      if color == :{{name.id}}
        @fore = ColorANSI::{{name.camelcase.id}}
        return self
      end
    {% end %}

    raise ArgumentError.new "Unknown color: #{color}"
  end

  def fore(@fore : Color) : self
    self
  end

  def back(color : Symbol) : self
    {% for name in COLORS %}
      if color == :{{name.id}}
        @back = ColorANSI::{{name.camelcase.id}}
        return self
      end
    {% end %}

    raise ArgumentError.new "Unknown color: #{color}"
  end

  def back(@back : Color) : self
    self
  end

  # Adds *mode* to the text's decorations.
  def mode(mode : Mode)
    @mode |= mode
    self
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

    if fore_is_default && back_is_default && mode.none? && last_color_is_default || @@last_color == color
      false
    else
      io << "\e["

      printed = false

      unless last_color_is_default
        io << Mode::None.code
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

      unless mode.none?
        printed_bright = false
        mode.each do |flag|
          # Enum#each yields each member flag. Bright and bold have the same value
          # and would show up as duplicate, so we need to handle this special case.
          if flag.bright?
            if printed_bright
              next
            else
              printed_bright = true
            end
          end
          io << ';' if printed
          io << flag.code
          printed = true
        end
      end

      io << 'm'

      true
    end
  end
end
