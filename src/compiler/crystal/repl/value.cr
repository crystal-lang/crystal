require "./repl"

struct Crystal::Repl::Value
  getter type : Type
  getter value : Nil |
                 Bool |
                 Char |
                 Int8 | UInt8 |
                 Int16 | UInt16 |
                 Int32 | UInt32 |
                 Int64 | UInt64 |
                 Float32 | Float64 |
                 String |
                 PointerWrapper |
                 Type

  def initialize(@value, @type : Type)
  end

  def truthy?
    case value
    when Nil
      false
    when Bool
      value == true
    else
      # TODO: missing pointer
      true
    end
  end
end
