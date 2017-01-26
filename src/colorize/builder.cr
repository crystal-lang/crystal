require "./object"
require "./style"

module Colorize
  def self.build
    Builder.new.tap do |io|
      yield io
    end
  end

  # `Builder` is a `IO` to colorize.
  class Builder
    include ::IO
    include ColorizableIO

    @colorize_when = When::Always

    # `Builder#colorize_when` is always `When::Always`, so it has no effect.
    def colorize_when=(policy)
    end

    def initialize
      @contents = Array(Object(String) | Object(Builder) | IO::Memory).new
    end

    def <<(object : Object(String))
      @contents << object
      self
    end

    def <<(object : Object)
      self << Object.new(object.object.to_s).style(object)
    end

    def surround(style : Style)
      @contents << Object.new(Builder.new.tap { |io| with io yield io }).style(style)
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

    def to_s(io)
      @contents.each do |content|
        io << content
      end
    end

    def to_s_without_colorize(io)
      io = IO.new io
      io.colorize_when = When::Never
      to_s io
    end

    def to_s_without_colorize
      String.build { |io| to_s_without_colorize io }
    end
  end
end
