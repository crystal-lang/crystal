module Colorize
  # `Color` is a union of available colors on a terminal.
  #
  # You can create `Color` by using `Colorize.parse_color` or `Colorize.parse_color?`.
  #
  # See [Wikipedia's article](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors).
  alias Color = ColorANSI | Color256 | ColorRGB

  # Parse `String` *color* as `Color`, or return `nil` when parse failed.
  #
  # ```
  # # ANSI colors
  # Colorize.parse_color? "red"        # => Colorize::ColorANSI::Red
  # Colorize.parse_color? "light_blue" # => Colorize::ColorANSI::Blue
  #
  # # 256 colors
  # Colorize.parse_color? "42"  # => Colorize::Color256(@value=42)
  # Colorize.parse_color? "111" # => Colorize::Color256(@value=111)
  #
  # # 32bit true colors
  # Colorize.parse_color? "#123"    # => Colorize::ColorRGB(@blue=51, @green=34, @red=17)
  # Colorize.parse_color? "#112233" # => Colorize::ColorRGB(@blue=51, @green=34, @red=17)
  #
  # Colorize.parse_color? "invalid" # => nil
  # ```
  #
  # See `Color256.parse?` and `ColorRGB.parse?`.
  def self.parse_color?(color)
    ColorANSI.parse?(color) || Color256.parse?(color) || ColorRGB.parse?(color)
  end

  # Parse `String` *color* as `Color`, or raise an error when parse failed.
  #
  # ```
  # # ANSI colors
  # Colorize.parse_color "red"        # => Colorize::ColorANSI::Red
  # Colorize.parse_color "light_blue" # => Colorize::ColorANSI::Blue
  #
  # # 256 colors
  # Colorize.parse_color "42"  # => Colorize::Color256(@value=42)
  # Colorize.parse_color "111" # => Colorize::Color256(@value=111)
  #
  # # 32bit true colors
  # Colorize.parse_color "#123"    # => Colorize::ColorRGB(@blue=51, @green=34, @red=17)
  # Colorize.parse_color "#112233" # => Colorize::ColorRGB(@blue=51, @green=34, @red=17)
  #
  # Colorize.parse_color "invalid" # raises ArgumentError
  # ```
  #
  # See `Color256.parse` and `ColorRGB.parse`.
  def self.parse_color(color)
    self.parse_color?(color) || raise "invalid color: #{color}"
  end

  # `ColorANSI` represents 8-color defined in ANSI escape sequence.
  #
  # The `value` means foreground color code.
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

    # Return foreground color code.
    def fore_code
      value.to_s
    end

    # Return background color code.
    def back_code
      (value + 10).to_s
    end
  end

  # `Color256` represents 256 color on a terminal.
  #
  #   - `0x00..0x07`: standard colors (as in `"\e[30m".."\e[37m"`)
  #   - `0x08..0x0F`: high intensity colors (as in `"\e[90m".."\e[97m"`)
  #   - `0x10..0xE7`: `6 * 6 * 6 = 216` colors (calculated by `16 + r * 36 + g * 6 + b`)
  #   - `0xE8..0xFF`: grayscale from black to white in 24 steps
  #
  # NOTE: It is also converted from `ColorRGB` by `ColorRGB#to_color256`.
  struct Color256
    # Color code value.
    getter value : UInt8

    # Create `Color256` from given *value*.
    def initialize(value)
      @value = value.to_u8
    end

    # Parse and create a new `Color256` from `String` *value*, or return `nil` when parse failed.
    #
    # ```
    # Colorize::Color256.parse? "111"   # => Colorize::Color256(@value=111)
    # Colorize::Color256.parse? "12345" # => nil
    # ```
    def self.parse?(value)
      if value = value.to_u8?
        new value
      end
    end

    # Parse and create a new `Color256` from `String` *value*, or raise an error when parse failed.
    #
    # ```
    # Colorize::Color256.parse "111"   # => Colorize::Color256(@value=111)
    # Colorize::Color256.parse "12345" # raises ArgumentError
    # ```
    def self.parse(value)
      parse?(css_color_code) || raise ArgumentError.new "invalid color: #{css_color_code}"
    end

    # Return foreground color code.
    def fore_code
      "38;5;#{value}"
    end

    # Return background color code.
    def back_code
      "48;5;#{value}"
    end

    # :nodoc:
    def default?
      false
    end

    # :nodoc:
    def_equals_and_hash value
  end

  # `ColorRGB` represents 24bit true color on a terminal.
  #
  # It is useful but supported by only newer terminals.
  struct ColorRGB
    # Red value
    getter red : UInt8
    # Green value
    getter green : UInt8
    # Blue value
    getter blue : UInt8

    # Create `ColorRGB` with *red*, *green* and *blue* values.
    def initialize(red, green, blue)
      @red = red.to_u8
      @green = green.to_u8
      @blue = blue.to_u8
    end

    # Parse and create a new `ColorRGB` from *css_color_code* like `"#112233"` and `"#123"`, or return `nil` when parse failed.
    #
    # ```
    # Colorize::ColorRGB.parse? "#112233" # => Colorize::Color256(@blue=51, @green=34, @red=17)
    # Colorize::ColorRGB.parse? "#123"    # => Colorize::Color256(@blue=51, @green=34, @red=17)
    # Colorize::ColorRGB.parse? "112233"  # => nil
    # ```
    def self.parse?(css_color_code)
      if css_color_code =~ /\A#(?:[[:xdigit:]]{6}|[[:xdigit:]]{3})\Z/
        if css_color_code.size == 4
          r = css_color_code[1].to_i(16).tap { |r| break r * 16 + r }
          g = css_color_code[2].to_i(16).tap { |g| break g * 16 + g }
          b = css_color_code[3].to_i(16).tap { |b| break b * 16 + b }
        else
          r = css_color_code[1..2].to_i 16
          g = css_color_code[3..4].to_i 16
          b = css_color_code[5..6].to_i 16
        end
        ColorRGB.new r, g, b
      end
    end

    # Parse and create a new `ColorRGB` from *css_color_code* like `"#112233"` and `"#123"`, or raise an error when parse failed.
    #
    # ```
    # Colorize::ColorRGB.parse "#112233" # => Colorize::Color256(@blue=51, @green=34, @red=17)
    # Colorize::ColorRGB.parse "#123"    # => Colorize::Color256(@blue=51, @green=34, @red=17)
    # Colorize::ColorRGB.parse "112233"  # raises ArgumentError
    # ```
    def self.parse(css_color_code)
      parse?(css_color_code) || raise ArgumentError.new "invalid color: #{css_color_code}"
    end

    # Return foreground color code.
    def fore_code
      "38;2;#{red};#{green};#{blue}"
    end

    # Return background color code.
    def back_code
      "48;2;#{red};#{green};#{blue}"
    end

    # Convert to `Color256`.
    def to_color256
      r = (red.to_f / 256 * 6).to_i
      g = (green.to_f / 256 * 6).to_i
      b = (blue.to_f / 256 * 6).to_i
      Color256.new 16 + r * 36 + g * 6 + b
    end

    # :nodoc:
    def default?
      false
    end

    # :nodoc:
    def_equals_and_hash red, green, blue
  end
end
