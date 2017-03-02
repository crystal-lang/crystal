require "./style_builder"
require "./when"

module Colorize
  # `ColorizableIO` is a mixin module for the `IO` which accepts escape sequence.
  module ColorizableIO
    # Whether to output escape sequence. See `When`.
    #
    # NOTE: `IO::FileDescriptor`'s default value is `When::Auto`. It works fine.
    getter colorize_when : When = When::Always

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
      @colorize_when = When.parse?(colorize_when.to_s) || raise ArgumentError.new("unknown policy: #{colorize_when}")
    end

    # Set *colorize_when* to `#colorize_when`.
    def colorize_when=(@colorize_when)
    end

    # Set *colorize_when* to `#colorize_when`, then invoke the block. After it, reset `#colorize_when` as old value.
    def colorize_when(colorize_when)
      old_when = @colorize_when
      begin
        self.colorize_when = colorize_when
        yield self
      ensure
        @colorize_when = old_when
      end
    end

    # It keeps last colorizing style for nesting.
    @last_style : StyleBuilder? = nil

    # Return `true` when this `IO` can output escape sequence on its `#colorize_when` policy.
    def output_escape_sequence?
      @colorize_when.output_escape_sequence?(self)
    end

    # Colorize the output in the block with *colorize* style.
    #
    # It outputs an escape sequence, then invokes the block. After all, it outputs reset escape sequence if needed.
    #
    # This method has a stack internally, so it keeps colorizing if nested.
    def surround(style) : self
      last_style = @last_style

      if !output_escape_sequence? || !style.enabled? || last_style.try &.same_style? style
        yield self
      else
        must_reset = colorize_write style, reset: !(last_style.nil? || last_style.all_default?)
        @last_style = style

        begin
          yield self
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

    # Return wrapped `::IO` object
    getter io

    # Return *io* itself if *io* is `ColorizableIO` already.
    def self.new(io : ColorizableIO, colorize_when = When::Always)
      io
    end

    # Wrap a given *io* with *colorize_when* policy.
    def initialize(@io : ::IO, colorize_when = When::Always)
      self.colorize_when = colorize_when
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
    #
    # If `self` is not `ColorizableIO`, it returns a new `IO` instance with *when_for_new* policy.
    # If `self` is `ColorizableIO` already, it returns itself.
    def to_colorizable(when_for_new = When::Always)
      Colorize::IO.new self, when_for_new
    end
  end
end

class IO::FileDescriptor
  include Colorize::ColorizableIO

  @colorize_when = Colorize::When::Auto
end
