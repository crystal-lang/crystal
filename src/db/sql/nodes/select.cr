require "./node"

class DB::Sql::Select < DB::Sql::Node
  getter froms
  getter projections
  getter conditions

  def initialize
    @froms = [] of Table
    @projections = [] of Node
    @conditions = [] of Node
  end

  def self.from(table)
    select = Select.new
    select.add_from table
    select
  end

  def add_from(table)
    @froms << table
    self
  end

  def project(column)
    @projections << column
    self
  end

  def where(condition)
    @conditions << condition
    self
  end

  def to_sql(dialect_class : Class)
    dialect = dialect_class.new
    dialect.visit self
    dialect.to_sql
  end
end
