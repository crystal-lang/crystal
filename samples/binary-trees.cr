# Copied with little modifications from: http://benchmarksgame.alioth.debian.org/u64q/benchmark.php?test=binarytrees&lang=yarv&id=1&data=u64q

class Node
  def initialize(@a : Node?, @b : Int32, @c : Node?)
  end

  property :a
  property :b
  property :c
end

def item_check(tree)
  tree = tree.not_nil!
  return tree.b if tree.a.nil?
  tree.b + item_check(tree.a) - item_check(tree.c)
end

def bottom_up_tree(item, depth)
  return Node.new(nil, item, nil) unless depth > 0
  item_item = 2 * item
  depth -= 1
  Node.new(bottom_up_tree(item_item - 1, depth), item, bottom_up_tree(item_item, depth))
end

max_depth = (ARGV[0]? || 15).to_i
min_depth = 4

max_depth = min_depth + 2 if min_depth + 2 > max_depth

stretch_depth = max_depth + 1
stretch_tree = bottom_up_tree(0, stretch_depth)

puts "stretch tree of depth #{stretch_depth}\t check: #{item_check(stretch_tree)}"
stretch_tree = nil

long_lived_tree = bottom_up_tree(0, max_depth)

min_depth.step(to: max_depth + 1, by: 2) do |depth|
  iterations = 2**(max_depth - depth + min_depth)

  check = 0

  (1..iterations).each do |i|
    temp_tree = bottom_up_tree(i, depth)
    check += item_check(temp_tree)

    temp_tree = bottom_up_tree(-i, depth)
    check += item_check(temp_tree)
  end

  puts "#{iterations * 2}\t trees of depth #{depth}\t check: #{check}"
end

puts "long lived tree of depth #{max_depth}\t check: #{item_check(long_lived_tree)}"
