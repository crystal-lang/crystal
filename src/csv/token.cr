require "csv"

# A token in a CSV. It consists of a `Kind` and a value.
# The value only makes sense when the *kind* is `Cell`.
struct CSV::Token
  # Token kinds.
  enum Kind
    Cell
    Newline
    Eof
  end

  # The `Kind`.
  property kind : Kind

  # The string value. Only makes sense for a `Cell`.
  property value : String

  # :nodoc:
  def initialize
    @kind = Kind::Cell
    @value = ""
  end
end
