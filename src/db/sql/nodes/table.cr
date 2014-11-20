require "./node"

class DB::Sql::Table < DB::Sql::Node
  getter name

  def initialize(@name)
  end

  def [](column_name)
    Column.new(column_name.to_s)
  end
end
