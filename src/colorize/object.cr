require "./io"

module Colorize
  # `Object` wraps given object to colorize with a style on terminal.
  #
  # It is usual created by `ObjectExtension#colorize`.
  struct Object(T)
    include StyleBuilder

    # Wrap a *object* to colorize with given values.
    def initialize(@object : T, fore = nil, back = nil, mode = nil)
      style fore, back, mode
    end

    # Return wrapped object.
    getter object

    # Overload for `IO`. See `IO#to_s`.
    def to_s(io : ColorizableIO)
      io << self
    end

    # Output `object` with this style.
    #
    # NOTE: When you use this method, you can't get auto TTY detection feature.
    # You should use `ColorizableIO` explicitly.
    def to_s(io : ::IO)
      IO.new(io) << self
    end

    # :nodoc:
    def_equals_and_hash fore, back, mode, object
  end

  # `ObjectExtension` is a mixin module for `::Object`.
  #
  # It adds `#colorize` method to create a new `Object` instance.
  module ObjectExtensions
    # Return a new `Object` instance to colorize with given values.
    def colorize(fore = nil, back = nil, mode = nil)
      Object.new(self, fore, back, mode)
    end
  end
end
