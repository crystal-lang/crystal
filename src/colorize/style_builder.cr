require "./color"
require "./mode"

# `StyleBuilder` is a mixin module for `Style` and `Object`.
#
# It provides builder methods for construct a style on a terminal.
module Colorize::StyleBuilder
  # Foreground color. See `Color`.
  property fore = ColorANSI::Default

  # Background color. See `Color`.
  property back = ColorANSI::Default

  # Activated text decoration modes. See `Mode`.
  property mode = Mode::None

  {% for color in ColorANSI.constants %}
    # Set `ColorANSI::{{color}}` to `#fore`, then return `self`.
    def {{color.underscore}}
      fore ColorANSI::{{color}}
    end

    # Set `ColorANSI::{{color}}` to `#back`, then return `self`.
    def on_{{color.underscore}}
      back ColorANSI::{{color}}
    end
  {% end %}

  {% for mode in Mode.constants.reject { |name| name == "All" || name == "None" } %}
    # Activate `Mode::{{mode}}` mode, then return `self`.
    def {{mode.underscore}}
      mode Mode::{{mode}}
    end
  {% end %}

  # Set specified *color* to `#fore`, then return `self`.
  #
  # Available colors are:
  #
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
  def fore(color : Symbol)
    fore ColorANSI.parse?(color.to_s) || raise ArgumentError.new "unknown color: #{color}"
  end

  # Set specified *color* to `#fore`, then return `self`.
  #
  # Such colors are available:
  #
  # ```
  # "red"
  # "green"
  # "#FF00FF"
  # "#FDD"
  # ```
  #
  # See `Colorize.parse_color`.
  def fore(color : String)
    fore Colorize.parse_color color
  end

  # Set specified *color* as `Color256` to `#fore`, then return `self`.
  def fore(color : Int)
    fore Color256.new color
  end

  # Set specified *color* to `#fore`, then return `self`.
  def fore(color : Color)
    @fore = color
    self
  end

  # Not change `#fore` if *color* is `nil`, and return `self`.
  def fore(color : Nil)
    self
  end

  # Set specified *color* to `#back`, then return `self`.
  #
  # Available colors are:
  #
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
  def back(color : Symbol)
    back ColorANSI.parse?(color.to_s) || raise ArgumentError.new "unknown color: #{color}"
  end

  # Set specified *color* to `#back`, then return `self`.
  #
  # Such colors are available:
  #
  # ```
  # "red"
  # "green"
  # "#FF00FF"
  # "#FDD"
  # ```
  #
  # See `Colorize.parse_color`.
  def back(color : String)
    back Colorize.parse_color color
  end

  # Set specified *color* as `Color256` to `#back`, then return `self`.
  def back(color : Int)
    back Color256.new color
  end

  # Set specified *color* to `#back`, then return `self`.
  def back(color : Color)
    @back = color
    self
  end

  # Not change `#back` if *color* is `nil`, and return `self`.
  def back(color : Nil)
    self
  end

  # Alias for `#back`.
  def on(color)
    back color
  end

  # Activate specified *mode*, then return `self`.
  #
  # Available text decoration modes are:
  #
  # ```
  # :bold
  # :bright
  # :dim
  # :underline
  # :blink
  # :reverse
  # :hidden
  # ```
  #
  # See `Mode`.
  def mode(mode : Symbol | String)
    mode Mode.parse?(mode.to_s) || raise ArgumentError.new "unknown mode: #{mode}"
  end

  # Activate specified *mode*, then return `self`.
  def mode(mode : Mode)
    @mode |= mode
    self
  end

  # Activate nothing, and return `self`.
  def mode(mode : Nil)
    self
  end

  # Set style, then return `self`.
  def style(style : StyleBuilder)
    style style.fore, style.back, style.mode
  end

  # :ditto:
  def style(fore = nil, back = nil, mode = nil)
    fore fore
    back back
    mode mode
  end

  # Return `true` if `#fore`, `#back` and `#mode` are still default.
  def all_default?
    fore.default? && back.default? && mode.none?
  end

  # Return `true` if `#fore`, `#back` and `#mode` are same as `other''s.
  def same_style?(other)
    fore == other.fore && back == other.back && mode == other.mode
  end
end
