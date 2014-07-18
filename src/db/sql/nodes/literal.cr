require "node"

class DB::Sql::Literal
  getter value

  def initialize(@value)
  end
end
