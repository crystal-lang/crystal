require "./node"

class DB::Sql::Column < DB::Sql::Node
  getter name

  def initialize(@name)
  end

  def eq(value : String)
    BinaryOp.new(self, :"==", Literal.new(value))
  end
end
