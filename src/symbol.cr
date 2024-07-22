# A symbol is a constant that is identified by a name without you having to give
# it a numeric value.
#
# ```
# :hello
# :welcome
# :"123"
# :"symbol with spaces"
# ```
#
# See [`Symbol` literals](https://crystal-lang.org/reference/syntax_and_semantics/literals/symbol.html) in the language reference.
#
# Internally a symbol is represented as an `Int32`, so it's very efficient.
#
# You can't dynamically create symbols. When you compile your program, each symbol
# gets assigned a unique number.
struct Symbol
  include Comparable(Symbol)

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.symbol(self)
  end

  # Compares symbol with other based on `String#<=>` method.
  # Returns `-1`, `0` or `1` depending on whether symbol is less than, equal to,
  # or greater than *other*.
  #
  # See `String#<=>` for more information.
  def <=>(other : Symbol)
    to_s <=> other.to_s
  end

  # Returns the symbol literal representation as a string.
  #
  # ```
  # :crystal.inspect # => ":crystal"
  # ```
  def inspect(io : IO) : Nil
    io << ':'

    value = to_s
    if Symbol.needs_quotes?(value)
      value.inspect(io)
    else
      value.to_s(io)
    end
  end

  # Appends the symbol's name to the passed `IO`.
  #
  # ```
  # :crystal.to_s # => "crystal"
  # ```
  def to_s(io : IO) : Nil
    io << to_s
  end

  # Determines if a string needs to be quoted to be used for a symbol literal.
  #
  # ```
  # Symbol.needs_quotes? "string"      # => false
  # Symbol.needs_quotes? "long string" # => true
  # ```
  def self.needs_quotes?(string) : Bool
    case string
    when "+", "-", "*", "&+", "&-", "&*", "/", "//", "==", "<", "<=", ">", ">=", "!", "!=", "=~", "!~"
      false
    when "&", "|", "^", "~", "**", "&**", ">>", "<<", "%", "[]", "<=>", "===", "[]?", "[]="
      false
    when "_"
      false
    else
      needs_quotes_for_named_argument?(string)
    end
  end

  # :nodoc:
  # Determines if a string needs to be quoted to be used for an external
  # parameter name or a named argument's key.
  def self.needs_quotes_for_named_argument?(string) : Bool
    case string
    when "", "_"
      true
    else
      string.each_char_with_index do |char, i|
        if i == 0 && char.ascii_number?
          return true
        end

        case char
        when .ascii_alphanumeric?, '_'
          # Nothing
        else
          return true
        end
      end
      false
    end
  end

  # :nodoc:
  # Appends *string* to *io* and quotes it if necessary.
  def self.quote_for_named_argument(io : IO, string : String) : Nil
    if needs_quotes_for_named_argument?(string)
      string.inspect(io)
    else
      io << string
    end
  end

  # :nodoc:
  # Returns *string* and quotes it if necessary.
  def self.quote_for_named_argument(string : String) : String
    if needs_quotes_for_named_argument?(string)
      string.inspect
    else
      string
    end
  end

  def clone
    self
  end
end
