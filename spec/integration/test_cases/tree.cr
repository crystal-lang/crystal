# output: !$accklorrssty

class Node
  def initialize(v)
    @value = v
  end

  def add(x)
    if x < @value
      if @left.nil?
        @left = Node.new(x)
      else
        @left.add(x)
      end
    else
      if @right.nil?
        @right = Node.new(x)
      else
        @right.add(x)
      end
    end
  end

  def print
    @left.print unless @left.nil?
    C.putchar @value
    @right.print unless @right.nil?
  end
end

root = Node.new('$')
"crystalrocks!".chars do |c|
  root.add c
end

root.print
C.putchar '\n'