require "./color"
require "./mode"
require "./when"

# `Builder` is a mixin module for `Style` and `Object`.
#
# It provides builder methods for construct a style on terminal.
module Colorize::Builder
  # Foreground color. See `Color`.
  property fore = ColorANSI::Default

  # Background color. See `Color`.
  property back = ColorANSI::Default

  # Activated text decoration modes. See `Mode`.
  property mode = Mode::None

  # When to output escape sequence. See `When`.
  property :when; @when = When::Auto

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

  {% for policy in When.constants %}
    # Set `When::{{policy}}` to `#when`, then return `self`.
    def {{policy.underscore}}
      self.when When::{{policy}}
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

  # Set specified *policy* to `#when`, then return `self`.
  #
  # Available policies are:
  #
  # ```
  # :auto
  # :always
  # :never
  # ```
  #
  # See `When`.
  def when(policy : Symbol | String)
    self.when When.parse?(policy.to_s) || raise ArgumentError.new "unknown policy: #{policy}"
  end

  # Set specified *policy* to `#when`, then return `self`.
  def when(policy : When)
    @when = policy
    self
  end

  # Not change `#when` if *policy* is `nil`, and return `self`.
  def when(policy : Nil)
    self
  end

  # Set `When::Always` to `#when` if *enabled* is `true`, or set `When::Never` to `#when` if *enabled* is `false`, then return `self`.
  def toggle(enabled)
    self.when enabled ? When::Auto : When::Never
  end

  # Return `true` if `#fore`, `#back` and `#mode` is still default.
  def all_default?
    fore.default? && back.default? && mode.none?
  end
end
