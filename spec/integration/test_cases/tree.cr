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
    putchar @value
    @right.print unless @right.nil?
  end
end

root = Node.new('$')
root.add 'c'
root.add 'r'
root.add 'y'
root.add 's'
root.add 't'
root.add 'a'
root.add 'l'
root.add 'r'
root.add 'o'
root.add 'c'
root.add 'k'
root.add 's'
root.add '!'

root.print
putchar '\n'