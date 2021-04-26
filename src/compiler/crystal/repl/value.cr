class Crystal::Repl::Value
  getter type : Type
  getter value : Nil | Bool | Int32

  def initialize(@value, @type : Type)
  end
end
