class DB::Sql::MysqlDialect
  def initialize
    @str = StringIO.new
  end

  def visit(node : Select)
    @str << "SELECT "
    node.projections.each_with_index do |projection, i|
      @str << ", " if i > 0
      visit projection
    end
    @str << " FROM "
    node.froms.each_with_index do |from, i|
      @str << ", " if i > 0
      visit from
    end
    if node.conditions.length > 0
      @str << " WHERE "
      node.conditions.each_with_index do |condition, i|
        @str << " AND " if i > 0
        visit condition
      end
    end
  end

  def visit(node : Table)
    quote node.name
  end

  def visit(node : Column)
    quote node.name
  end

  def visit(node : BinaryOp)
    visit node.left
    case node.op
    when :"=="
      @str << " = "
    else
      raise "unknown binary op: #{node.op}"
    end
    visit node.right
  end

  def visit(node : Literal)
    escape node.value
  end

  def quote(name)
    @str << '`'
    @str << name
    @str << '`'
  end

  def escape(string : String)
    @str << '\''
    @str << string
    @str << '\''
  end

  def to_sql
    @str.to_s
  end
end
