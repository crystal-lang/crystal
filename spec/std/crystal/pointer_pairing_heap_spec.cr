require "spec"
require "../../../src/crystal/pointer_pairing_heap"

private struct Node
  getter key : Int32

  include Crystal::PointerPairingHeap::Node

  def initialize(@key : Int32)
  end

  def heap_compare(other : Pointer(self)) : Bool
    key < other.value.key
  end

  def inspect(io : IO, indent = 0) : Nil
    prv = @heap_previous
    nxt = @heap_next
    chd = @heap_child

    indent.times { io << ' ' }
    io << "Node value=" << key
    io << " prv=" << prv.try(&.value.key)
    io << " nxt=" << nxt.try(&.value.key)
    io << " chd=" << chd.try(&.value.key)
    io.puts

    node = heap_child?
    while node
      node.value.inspect(io, indent + 2)
      node = node.value.heap_next?
    end
  end
end

describe Crystal::PointerPairingHeap do
  it "#add" do
    heap = Crystal::PointerPairingHeap(Node).new
    node1 = Node.new(1)
    node2 = Node.new(2)
    node2b = Node.new(2)
    node3 = Node.new(3)

    # can add distinct nodes
    heap.add(pointerof(node3))
    heap.add(pointerof(node1))
    heap.add(pointerof(node2))

    # can add duplicate key (different nodes)
    heap.add(pointerof(node2b))

    # can't add same node twice
    expect_raises(ArgumentError) { heap.add(pointerof(node1)) }

    # can re-add removed nodes
    heap.delete(pointerof(node3))
    heap.add(pointerof(node3))

    heap.shift?.should eq(pointerof(node1))
    heap.add(pointerof(node1))
  end

  it "#shift?" do
    heap = Crystal::PointerPairingHeap(Node).new
    nodes = StaticArray(Node, 10).new { |i| Node.new(i) }

    # insert in random order
    (0..9).to_a.shuffle.each do |i|
      heap.add nodes.to_unsafe + i
    end

    # removes in ascending order
    10.times do |i|
      node = heap.shift?
      node.should eq(nodes.to_unsafe + i)
    end
  end

  it "#delete" do
    heap = Crystal::PointerPairingHeap(Node).new
    nodes = StaticArray(Node, 10).new { |i| Node.new(i) }

    # insert in random order
    (0..9).to_a.shuffle.each do |i|
      heap.add nodes.to_unsafe + i
    end

    # remove some values
    heap.delete(nodes.to_unsafe + 3)
    heap.delete(nodes.to_unsafe + 7)
    heap.delete(nodes.to_unsafe + 1)

    # remove tail
    heap.delete(nodes.to_unsafe + 9)

    # remove head
    heap.delete(nodes.to_unsafe + 0)

    # repeatedly delete min
    [2, 4, 5, 6, 8].each do |i|
      heap.shift?.should eq(nodes.to_unsafe + i)
    end
    heap.shift?.should be_nil
  end

  it "adds 1000 nodes then shifts them in order" do
    heap = Crystal::PointerPairingHeap(Node).new

    nodes = StaticArray(Node, 1000).new { |i| Node.new(i) }
    (0..999).to_a.shuffle.each { |i| heap.add(nodes.to_unsafe + i) }

    i = 0
    while node = heap.shift?
      node.value.key.should eq(i)
      i += 1
    end
    i.should eq(1000)

    heap.shift?.should be_nil
  end

  it "randomly shift while we add nodes" do
    heap = Crystal::PointerPairingHeap(Node).new

    nodes = uninitialized StaticArray(Node, 1000)
    (0..999).to_a.shuffle.each_with_index { |i, j| nodes[j] = Node.new(i) }

    i = 0
    removed = 0

    # regularly calls delete-min while we insert
    loop do
      if rand(0..5) == 0
        removed += 1 if heap.shift?
      else
        heap.add(nodes.to_unsafe + i)
        break if (i += 1) == 1000
      end
    end

    # exhaust the heap
    while heap.shift?
      removed += 1
    end

    # we must have added and removed all nodes _once_
    i.should eq(1000)
    removed.should eq(1000)
  end
end
