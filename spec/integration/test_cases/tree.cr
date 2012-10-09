# output: !$accklorrssty

class Node
  def initialize(v)
    @value = v
    @has_left = @has_right = false
  end

  def add(x)
    if x < @value
      if @has_left
        @left.add(x)
      else
        @left = Node.new(x)
        @has_left = true
      end
    else
      if @has_right
        @right.add(x)
      else
        @right = Node.new(x)
        @has_right = true
      end
    end
  end

  def print
    @left.print if @has_left
    putchar @value
    @right.print if @has_right
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