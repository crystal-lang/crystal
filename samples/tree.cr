class Node
  def initialize(v)
    @value = v
  end

  def add(x)
    if x < @value
      if @left
        @left.add(x)
      else
        @left = Node.new(x)
      end
    else
      if @right
        @right.add(x)
      else
        @right = Node.new(x)
      end
    end
  end

  def print
    @left.print if @left
    print @value
    @right.print if @right
  end
end

root = Node.new('$')
"crystalrocks!".each_char do |c|
  root.add c
end

root.print #=> !$accklorrssty
puts
