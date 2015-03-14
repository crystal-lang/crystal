struct Symbol
  include Comparable(Symbol)

  def <=>(other : Symbol)
    to_s <=> other.to_s
  end
  
  def inspect(io : IO)
    io << ":"

    value = to_s
    if Symbol.needs_quotes?(value)
      value.inspect(io)
    else
      value.to_s(io)
    end
  end

  def to_s(io : IO)
    io << to_s
  end

  # Determines if a string needs to be quoted to be used for a symbol.
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
