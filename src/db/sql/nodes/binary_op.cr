require "node"

class DB::Sql::BinaryOp < DB::Sql::Node
  getter left
  getter op
  getter right

  def initialize(@left, @op, @right)
  end
end
