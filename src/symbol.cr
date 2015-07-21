# A symbol is a constant that is identified by a name without you having to give
# it a numeric value.
#
# ```
# :hello
# :welcome
# :"symbol with spaces"
# ```
#
# Internally a symbol is represented as an `Int32`, so it's very efficient.
#
# You can't dynamically create symbols: when you compile your program each symbol
# gets assigned a unique number.
struct Symbol
  include Comparable(Symbol)

  # Compares symbol with other based on `String#<=>` method. Returns -1, 0
  # or +1 depending on whether symbol is less than, equal to, or greater than
  # other_symbol.
  # See `String#<=>` for more information.
  def <=>(other : Symbol)
    to_s <=> other.to_s
  end

  # Returns the symbol literal representation as a string.
  #
  # ```
  # :crystal.inspect # => ":crystal"
  # ```
  def inspect(io : IO)
    io << ":"

    value = to_s
    if Symbol.needs_quotes?(value)
      value.inspect(io)
    else
      value.to_s(io)
    end
  end

  # Appends the symbol's name to the passed IO.
  #
  # ```
  # :crystal.to_s # => "crystal"
  # ```
  def to_s(io : IO)
    io << to_s
  end

  # Determines if a string needs to be quoted to be used for a symbol.
  #
  # ```
  # Symbol.needs_quotes? "string"      # => false
  # Symbol.needs_quotes? "long string" # => true
  # ```
  def self.needs_quotes?(string)
    case string
    when "+", "-", "*", "/", "==", "<", "<=", ">", ">=", "!", "!=", "=~", "!~"
      # Nothing
    when "&", "|", "^", "~", "**", ">>", "<<", "%", "[]", "<=>", "===", "[]?", "[]="
      # Nothing
    else
      string.each_char do |char|
        case char
        when '0'..'9', 'A'..'Z', 'a'..'z', '_'
          # Nothing
        else
          return true
        end
      end
    end
    false
  end
end
