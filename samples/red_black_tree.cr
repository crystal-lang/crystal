# Copied with little modifications from: https://github.com/rubinius/rubinius-benchmark/blob/master/real_world/bench_red_black_tree.rb

class RedBlackTree
  class Node
    property :color
    property :key
    property! :left
    property! :right
    property! parent : self

    RED    = :red
    BLACK  = :black
    COLORS = [RED, BLACK]

    def initialize(@key : Int32, @color = RED)
      @left = @right = @parent = NilNode.instance
    end

    def black?
      color == BLACK
    end

    def red?
      color == RED
    end

    def nil_node?
      false
    end
  end

  class NilNode < Node
    def self.instance
      @@instance ||= RedBlackTree::NilNode.new
    end

    def initialize
      @key = 0
      @color = BLACK
      @left = @right = @parent = self
    end

    def nil_node?
      true
    end
  end

  #  include Enumerable

  property root : Node
  property :size

  def initialize
    @root = NilNode.instance
    @size = 0
  end

  def add(key)
    insert(Node.new(key))
  end

  def insert(x)
    insert_helper(x)

    x.color = Node::RED
    while x != root && x.parent.color == Node::RED
      if x.parent == x.parent.parent.left
        y = x.parent.parent.right
        if !y.nil_node? && y.color == Node::RED
          x.parent.color = Node::BLACK
          y.color = Node::BLACK
          x.parent.parent.color = Node::RED
          x = x.parent.parent
        else
          if x == x.parent.right
            x = x.parent
            left_rotate(x)
          end
          x.parent.color = Node::BLACK
          x.parent.parent.color = Node::RED
          right_rotate(x.parent.parent)
        end
      else
        y = x.parent.parent.left
        if !y.nil_node? && y.color == Node::RED
          x.parent.color = Node::BLACK
          y.color = Node::BLACK
          x.parent.parent.color = Node::RED
          x = x.parent.parent
        else
          if x == x.parent.left
            x = x.parent
            right_rotate(x)
          end
          x.parent.color = Node::BLACK
          x.parent.parent.color = Node::RED
          left_rotate(x.parent.parent)
        end
      end
    end
    root.color = Node::BLACK
  end

  def <<(x)
    insert(x)
  end

  def delete(z)
    y = (z.left.nil_node? || z.right.nil_node?) ? z : successor(z)
    x = y.left.nil_node? ? y.right : y.left
    x.parent = y.parent

    if y.parent.nil_node?
      self.root = x
    else
      if y == y.parent.left
        y.parent.left = x
      else
        y.parent.right = x
      end
    end

    z.key = y.key if y != z

    if y.color == Node::BLACK
      delete_fixup(x)
    end

    self.size -= 1
    y
  end

  def minimum(x = root)
    while !x.left.nil_node?
      x = x.left
    end
    x
  end

  def maximum(x = root)
    while !x.right.nil_node?
      x = x.right
    end
    x
  end

  def successor(x)
    if !x.right.nil_node?
      return minimum(x.right)
    end
    y = x.parent
    while !y.nil_node? && x == y.right
      x = y
      y = y.parent
    end
    y
  end

  def predecessor(x)
    if !x.left.nil_node?
      return maximum(x.left)
    end
    y = x.parent
    while !y.nil_node? && x == y.left
      x = y
      y = y.parent
    end
    y
  end

  def inorder_walk(x = root)
    x = self.minimum
    while !x.nil_node?
      yield x.key
      x = successor(x)
    end
  end

  def each(x = root)
    inorder_walk(x) { |k| yield k }
  end

  def reverse_inorder_walk(x = root)
    x = self.maximum
    while !x.nil_node?
      yield x.key
      x = predecessor(x)
    end
  end

  def reverse_each(x = root)
    reverse_inorder_walk(x) { |k| yield k }
  end

  def search(key, x = root)
    while !x.nil_node? && x.key != key
      x = (key < x.key) ? x.left : x.right
    end
    x
  end

  def empty?
    self.root.nil_node?
  end

  def black_height(x = root)
    height = 0
    while !x.nil_node?
      x = x.left
      height += 1 if x.nil_node? || x.black?
    end
    height
  end

  private def left_rotate(x)
    raise "x.right is nil!" if x.right.nil_node?
    y = x.right
    x.right = y.left
    y.left.parent = x if !y.left.nil_node?
    y.parent = x.parent
    if x.parent.nil_node?
      self.root = y
    else
      if x == x.parent.left
        x.parent.left = y
      else
        x.parent.right = y
      end
    end
    y.left = x
    x.parent = y
  end

  private def right_rotate(x)
    raise "x.left is nil!" if x.left.nil_node?
    y = x.left
    x.left = y.right
    y.right.parent = x if !y.right.nil_node?
    y.parent = x.parent
    if x.parent.nil_node?
      self.root = y
    else
      if x == x.parent.left
        x.parent.left = y
      else
        x.parent.right = y
      end
    end
    y.right = x
    x.parent = y
  end

  private def insert_helper(z)
    y = NilNode.instance
    x = root
    while !x.nil_node?
      y = x
      x = (z.key < x.key) ? x.left : x.right
    end
    z.parent = y
    if y.nil_node?
      self.root = z
    else
      z.key < y.key ? y.left = z : y.right = z
    end
    self.size += 1
  end

  private def delete_fixup(x)
    while x != root && x.color == Node::BLACK
      if x == x.parent.left
        w = x.parent.right
        if w.color == Node::RED
          w.color = Node::BLACK
          x.parent.color = Node::RED
          left_rotate(x.parent)
          w = x.parent.right
        end
        if w.left.color == Node::BLACK && w.right.color == Node::BLACK
          w.color = Node::RED
          x = x.parent
        else
          if w.right.color == Node::BLACK
            w.left.color = Node::BLACK
            w.color = Node::RED
            right_rotate(w)
            w = x.parent.right
          end
          w.color = x.parent.color
          x.parent.color = Node::BLACK
          w.right.color = Node::BLACK
          left_rotate(x.parent)
          x = root
        end
      else
        w = x.parent.left
        if w.color == Node::RED
          w.color = Node::BLACK
          x.parent.color = Node::RED
          right_rotate(x.parent)
          w = x.parent.left
        end
        if w.right.color == Node::BLACK && w.left.color == Node::BLACK
          w.color = Node::RED
          x = x.parent
        else
          if w.left.color == Node::BLACK
            w.right.color = Node::BLACK
            w.color = Node::RED
            left_rotate(w)
            w = x.parent.left
          end
          w.color = x.parent.color
          x.parent.color = Node::BLACK
          w.left.color = Node::BLACK
          right_rotate(x.parent)
          x = root
        end
      end
    end
    x.color = Node::BLACK
  end
end

class RedBlackTreeRunner
  property :tree

  def initialize(n = 10_000)
    @n = n

    random = Random.new(1234) # repeatable random seq
    @a1 = Array(Int32).new(n) { rand(99_999) }

    random = Random.new(4321) # repeatable random seq
    @a2 = Array(Int32).new(n) { rand(99_999) }

    @tree = RedBlackTree.new
  end

  def run_delete
    @tree = RedBlackTree.new
    @n.times { |i| @tree.add(i) }
    @n.times { @tree.delete(@tree.root) }
    tree.size
  end

  def run_add
    @tree = RedBlackTree.new
    @a1.each { |e| @tree.add(e) }
    tree.size
  end

  def run_search
    s = c = 0
    @a2.each { |e| c += 1; s += @tree.search(e).key % 3 }
    [s, c]
  end

  def run_inorder_walk
    s = 0
    c = 0
    @tree.inorder_walk { |key| c += 1; s += key % 3 }
    [s, c]
  end

  def run_reverse_inorder_walk
    s = 0
    c = 0
    @tree.reverse_inorder_walk { |key| c += 1; s += key % 3 }
    [s, c]
  end

  def run_min
    s = 0
    @n.times { s += @tree.minimum.key }
    s
  end

  def run_max
    s = 0_u64
    @n.times { s += @tree.maximum.key }
    s
  end
end

def bench(name, n = 1)
  t = Time.now
  print "#{name}: "
  res = nil
  n.times do
    res = yield
  end
  puts "#{Time.now - t}, res: #{res}"
end

t = Time.now

b = RedBlackTreeRunner.new 100_000
bench("delete", 10) { b.run_delete }
bench("add", 10) { b.run_add }
bench("search", 10) { b.run_search }
bench("walk", 100) { b.run_inorder_walk }
bench("reverse_walk", 100) { b.run_reverse_inorder_walk }
bench("min", 100) { b.run_min }
bench("max", 100) { b.run_max }

puts "summary time: #{Time.now - t}"
