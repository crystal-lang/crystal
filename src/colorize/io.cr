require "./style_builder"
require "./when"

module Colorize
  # `ColorizableIO` is a mixin module for the `IO` which accepts escape sequence.
  module ColorizableIO
    # Whether to output escape sequence. See `When`.
    #
    #   - `IO::FileDescriptor`'s default value is `When::Auto`.
    #   - `Colorize::IO`'s default value is `When::Always`.
    getter colorize_when : When

    # Set *colorize_when* to `#colorize_when`.
    #
    # It parses given value by `When.parse`. Available policies are:
    #
    # ```
    # :auto
    # :always
    # :never
    # ```
    #
    # See `When` for each values details.
    def colorize_when=(colorize_when : String | Symbol)
      self.colorize_when = When.parse?(colorize_when.to_s) || raise ArgumentError.new("unknown policy: #{colorize_when}")
    end

    # Set *colorize_when* to `#colorize_when`.
    def colorize_when=(@colorize_when)
    end

    # Overload for `Object`.
    def <<(colorize : Object)
      surround(colorize) do |io|
        io << colorize.object
      end
      self
    end

    # It keeps last colorizing style for nesting.
    @last_style : StyleBuilder? = nil

    # Return `true` when this `IO` can output escape sequence on its `#colorize_when` policy.
    def output_escape_sequence?
      colorize_when.output_escape_sequence?(self)
    end

    # Colorize the output in the block with *colorize* style.
    #
    # It outputs an escape sequence, then invokes the block. After all, it outputs reset escape sequence if needed.
    #
    # This method has a stack internally, so it keeps colorizing if nested.
    def surround(style) : self
      last_style = @last_style

      if !output_escape_sequence? || last_style.try &.same_style? style
        with self yield self
      else
        must_reset = colorize_write style, reset: !(last_style.nil? || last_style.all_default?)
        @last_style = style

        begin
          with self yield self
        ensure
          @last_style = last_style
          if must_reset
            if last_style
              colorize_write last_style, reset: !style.all_default?
            else
              colorize_reset
            end
          end
        end
      end

      self
    end

    # Output escape sequence to reset.

    # :nodoc:
    def colorize_reset
      self << "\e[0m"
    end

    # Write escape sequence to colorize with *style*.
    # If *reset* is `true`, it outputs reset escape sequence before applying *style*.
    #
    # It returns `true` if it outputs some escape sequence, otherwise returns `false`.

    # :nodoc:
    def colorize_write(style, reset = false)
      return false if style.all_default? && !reset

      self << "\e["

      printed = false

      if reset
        self << "0"
        printed = true
      end

      unless style.fore.default?
        self << ";" if printed
        self << style.fore.fore_code
        printed = true
      end

      unless style.back.default?
        self << ";" if printed
        self << style.back.back_code
        printed = true
      end

      unless style.mode.none?
        style.mode.codes do |code|
          self << ";" if printed
          self << code
          printed = true
        end
      end

      self << "m"

      true
    end
  end

  # `IO` wraps given `::IO` to colorize.
  #
  # It is usual created by `IOExtension#to_colorizable`.
  class IO
    include ::IO
    include ColorizableIO

    @colorize_when = When::Always

    # Return wrapped `::IO` object
    getter io

    # Return *io*.
    def self.new(io : ColorizableIO)
      io
    end

    # Wrap a `::IO`.
    def initialize(@io : ::IO)
    end

    # Delegate to `#io`.
    def write(slice : Bytes)
      @io.write slice
    end

    # Delegate to `#io`.
    def read(slice : Bytes)
      @io.read slice
    end
  end

  # `IOExtension` is a mixin module for `::IO`.
  #
  # It adds `#to_colorizable` method to create a new `ColorizableIO` instance.
  module IOExtension
    # Return `ColorizableIO` to colorize the output to `self`.
    # If `self` is not `ColorizableIO`, it returns a new `IO` instance.
    # If `self` is `ColorizableIO` already, it returns itself.
    def to_colorizable
      return self if is_a?(ColorizableIO)
      Colorize::IO.new self
    end
  end
end
