struct Crystal::Repl::Value
  getter type : Type
  getter value : Nil | Bool | Char | Int32 | UInt64 | String | Pointer(Void) | Type

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
