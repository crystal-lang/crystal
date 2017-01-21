require "./builder"
require "./io"

# `Object` wraps given object to colorize with a style on terminal.
#
# It is usual created by `ObjectExtension#colorize`.
struct Colorize::Object(T)
  include Builder

  # Wrap a *object*.
  def initialize(@object : T)
  end

  # Return wrapped object.
  getter object

  # Output colorized object with this style.
  def to_s(io)
    Colorize.surround(self, io) do
      @object.to_s io
    end
  end

  def_equals_and_hash fore, back, mode, :when, object
end
