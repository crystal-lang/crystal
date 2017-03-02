require "./object"
require "./style"

module Colorize
  # Create a new `Builder`, then invoke the block and return this builder.
  def self.build
    Builder.new.tap do |io|
      yield io
    end
  end

  # `Builder` is a `IO` to colorize.
  #
  # Its `#colorize_when` is always `When::Always` because it delegates given `::IO` on `#to_s` to colorize the output.
  #
  # It is useful when we cannot decide the output is colorized on creation, for example `Exception` message.
  class Builder
    include ::IO
    include ColorizableIO

    @colorize_when = When::Always

    # `#colorize_when` is always `When::Always`, so it has no effect.
    def colorize_when=(policy)
    end

    # Create a new `Builder`.
    def initialize
      @contents = Array(Object(String) | Object(Builder) | IO::Memory).new
    end

    # :nodoc:
    def <<(object : Object(String))
      @contents << object
      self
    end

    # :nodoc:
    def <<(object : Object)
      self << Object.new(object.object.to_s).style(object)
    end

    # :nodoc:
    def surround(style)
      @contents << Object.new(Builder.new.tap { |io| yield io }).style(style)
    end

    # :nodoc:
    def write(slice : Bytes)
      unless (io = @contents.last?).is_a?(IO::Memory)
        io = IO::Memory.new
        @contents << io
      end
      io.write slice
    end

    # :nodoc:
    def read(slice : Bytes)
      raise "Not implemented"
    end

    # Output contents to *io*.
    #
    # Whether to colorize the output depends on *io*'s colorize policy.
    def to_s(io)
      @contents.each do |content|
        io << content
      end
    end

    # Output contents to *io* without color.
    def to_s_without_colorize(io)
      IO.new(io).colorize_when(When::Never) do |io|
        to_s io
      end
    end

    # Return contents without color.
    def to_s_without_colorize
      String.build { |io| to_s_without_colorize io }
    end
  end
end
