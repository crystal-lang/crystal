class Node
  @left : self?
  @right : self?

  def initialize(@value : Char)
  end

  def add(x)
    if x < @value
      if left = @left
        left.add(x)
      else
        @left = Node.new(x)
      end
    else
      if right = @right
        right.add(x)
      else
        @right = Node.new(x)
      end
    end
  end

  def print
    @left.try &.print
    print @value
    @right.try &.print
  end
end

root = Node.new('$')
"crystalrocks!".each_char do |c|
  root.add c
end

root.print # => !$accklorrssty
puts
