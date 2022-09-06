# A struct that captues line and column information.
# The absence of line and column information is signaled
# by having `line` be zero, as lines in a file start by 1.
record Crystal::LineAndColumn, line : Int32, column : Int32 do
  def empty? : Bool
    line == 0
  end

  def or(other : LineAndColumn) : LineAndColumn
    empty? ? other : self
  end

  def or(other : Nil) : LineAndColumn
    self
  end

  def self.empty : LineAndColumn
    new(0, 0)
  end
end
