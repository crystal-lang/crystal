# Havlak benchmark: https://code.google.com/p/multi-language-bench/
# Crystal Implementation (translated from Python version)

# Intel i5 2.5GHz
# crystal: 26.5s 359Mb
# c++:     28.2s 150Mb
# java:    31.5s 909Mb
# scala:   66.8s 316Mb
# go:      67.7s 456Mb
# python:  958.4s 713Mb

class BasicBlock
  def initialize(@name : Int32)
    @in_edges = [] of BasicBlock
    @out_edges = [] of BasicBlock
  end

  property :in_edges
  property :out_edges

  def to_s(io)
    io << "BB#"
    io << @name
  end
end

struct BasicBlockEdge
  @from : BasicBlock
  @to : BasicBlock

  def initialize(cfg, from_name, to_name)
    @from = cfg.create_node(from_name)
    @to = cfg.create_node(to_name)
    @from.out_edges << @to
    @to.in_edges << @from
  end

  def self.add(cfg, from_name, to_name)
    edge = new(cfg, from_name, to_name)
    cfg.add_edge(edge)
  end
end

class CFG
  def initialize
    @basic_block_map = {} of Int32 => BasicBlock
    @edge_list = [] of BasicBlockEdge
  end

  property start_node : BasicBlock?
  property :basic_block_map

  def create_node(name)
    node = (@basic_block_map[name] ||= BasicBlock.new(name))
    @start_node ||= node
    node
  end

  def add_edge(edge)
    @edge_list << edge
  end

  def num_nodes
    @basic_block_map.size
  end
end

class SimpleLoop
  def initialize
    @basic_blocks = Set(BasicBlock).new
    @children = Set(SimpleLoop).new
    @parent = nil
    @header = nil

    @root = false
    @reducible = true
    @counter = 0
    @nesting_level = 0
    @depth_level = 0
  end

  property :counter
  property? :reducible
  property? :root
  getter :parent
  property :depth_level
  property :children
  getter :nesting_level

  def add_node(bb)
    @basic_blocks.add(bb)
  end

  def add_child_loop(l)
    @children.add(l)
  end

  def parent=(parent : SimpleLoop)
    @parent = parent
    parent.add_child_loop(self)
  end

  def header=(bb : BasicBlock)
    @basic_blocks.add(bb)
    @header = bb
  end

  def nesting_level=(level)
    @nesting_level = level
    @root = true if level == 0
  end
end

class LSG
  @@loop_counter = 0

  @root : SimpleLoop

  def initialize
    @loops = [] of SimpleLoop
    @root = create_new_loop
    @root.nesting_level = 0
    add_loop(@root)
  end

  def create_new_loop
    s = SimpleLoop.new
    s.counter = @@loop_counter += 1
    s
  end

  def add_loop(l)
    @loops << l
  end

  def calculate_nesting_level
    @loops.each do |liter|
      liter.parent = @root if !liter.root? && liter.parent == nil
    end

    calculate_nesting_level_rec(@root, 0)
  end

  def calculate_nesting_level_rec(l, depth)
    l.depth_level = depth
    l.children.each do |liter|
      calculate_nesting_level_rec(liter, depth + 1)
      l.nesting_level = Math.max(l.nesting_level, 1 + liter.nesting_level)
    end
  end

  def num_loops
    @loops.size
  end
end

class UnionFindNode
  def initialize
    @parent = nil
    @bb = nil
    @l = nil
    @dfs_number = 0
  end

  def init_node(bb, dfs_number)
    @parent = self
    @bb = bb
    @dfs_number = dfs_number
  end

  property bb : BasicBlock?
  property parent : self?
  property dfs_number : Int32
  property l : SimpleLoop?

  def find_set
    node_list = [] of UnionFindNode

    node = self
    while node != node.parent
      parent = node.parent.not_nil!
      node_list << node if parent != parent.parent
      node = parent
    end

    node_list.each { |iter| iter.parent = node.parent }

    node
  end

  def union(union_find_node)
    @parent = union_find_node
  end
end

class HavlakLoopFinder
  BB_TOP         = 0 # uninitialized
  BB_NONHEADER   = 1 # a regular BB
  BB_REDUCIBLE   = 2 # reducible loop
  BB_SELF        = 3 # single BB loop
  BB_IRREDUCIBLE = 4 # irreducible loop
  BB_DEAD        = 5 # a dead BB
  BB_LAST        = 6 # Sentinel

  # Marker for uninitialized nodes.
  UNVISITED = -1

  # Safeguard against pathologic algorithm behavior.
  MAXNONBACKPREDS = (32 * 1024)

  def initialize(@cfg : CFG, @lsg : LSG)
  end

  def ancestor?(w, v, last)
    w <= v <= last[w]
  end

  def dfs(current_node, nodes, number, last, current)
    nodes[current].init_node(current_node, current)
    number[current_node] = current

    lastid = current
    current_node.out_edges.each do |target|
      if number[target] == UNVISITED
        lastid = dfs(target, nodes, number, last, lastid + 1)
      end
    end

    last[number[current_node]] = lastid
    lastid
  end

  def find_loops
    start_node = @cfg.start_node
    return 0 unless start_node
    size = @cfg.num_nodes

    non_back_preds = Array.new(size) { Set(Int32).new }
    back_preds = Array.new(size) { Array(Int32).new }
    number = {} of BasicBlock => Int32
    header = Array.new(size, 0)
    types = Array.new(size, 0)
    last = Array.new(size, 0)
    nodes = Array.new(size) { UnionFindNode.new }

    # Step a:
    #   - initialize all nodes as unvisited.
    #   - depth-first traversal and numbering.
    #   - unreached BB's are marked as dead.
    #
    @cfg.basic_block_map.each_value { |v| number[v] = UNVISITED }
    dfs(start_node, nodes, number, last, 0)

    # Step b:
    #   - iterate over all nodes.
    #
    #   A backedge comes from a descendant in the DFS tree, and non-backedges
    #   from non-descendants (following Tarjan).
    #
    #   - check incoming edges 'v' and add them to either
    #     - the list of backedges (back_preds) or
    #     - the list of non-backedges (non_back_preds)
    #
    size.times do |w|
      header[w] = 0
      types[w] = BB_NONHEADER

      node_w = nodes[w].bb
      if node_w
        node_w.in_edges.each do |nodeV|
          v = number[nodeV]
          if v != UNVISITED
            if ancestor?(w, v, last)
              back_preds[w] << v
            else
              non_back_preds[w].add(v)
            end
          end
        end
      else
        types[w] = BB_DEAD
      end
    end

    # Start node is root of all other loops.
    header[0] = 0

    # Step c:
    #
    # The outer loop, unchanged from Tarjan. It does nothing except
    # for those nodes which are the destinations of backedges.
    # For a header node w, we chase backward from the sources of the
    # backedges adding nodes to the set P, representing the body of
    # the loop headed by w.
    #
    # By running through the nodes in reverse of the DFST preorder,
    # we ensure that inner loop headers will be processed before the
    # headers for surrounding loops.
    #
    (size - 1).downto(0) do |w|
      # this is 'P' in Havlak's paper
      node_pool = [] of UnionFindNode

      node_w = nodes[w].bb
      if node_w # dead BB

        # Step d:
        back_preds[w].each do |v|
          if v != w
            node_pool << nodes[v].find_set
          else
            types[w] = BB_SELF
          end
        end

        # Copy node_pool to work_list.
        #
        work_list = node_pool.dup

        types[w] = BB_REDUCIBLE if node_pool.size != 0

        # work the list...
        #
        while !work_list.empty?
          x = work_list.shift

          # Step e:
          #
          # Step e represents the main difference from Tarjan's method.
          # Chasing upwards from the sources of a node w's backedges. If
          # there is a node y' that is not a descendant of w, w is marked
          # the header of an irreducible loop, there is another entry
          # into this loop that avoids w.
          #

          # The algorithm has degenerated. Break and
          # return in this case.
          #
          non_back_size = non_back_preds[x.dfs_number].size
          return 0 if non_back_size > MAXNONBACKPREDS

          non_back_preds[x.dfs_number].each do |iter|
            y = nodes[iter]
            ydash = y.find_set

            if !ancestor?(w, ydash.dfs_number, last)
              types[w] = BB_IRREDUCIBLE
              non_back_preds[w].add(ydash.dfs_number)
            else
              if ydash.dfs_number != w && !node_pool.includes?(ydash)
                work_list << ydash
                node_pool << ydash
              end
            end
          end
        end

        # Collapse/Unionize nodes in a SCC to a single node
        # For every SCC found, create a loop descriptor and link it in.
        #
        if (node_pool.size > 0) || (types[w] == BB_SELF)
          l = @lsg.create_new_loop

          l.header = node_w
          l.reducible = types[w] != BB_IRREDUCIBLE

          # At this point, one can set attributes to the loop, such as:
          #
          # the bottom node:
          #    iter  = back_preds(w).begin();
          #    loop bottom is: nodes(iter).node;
          #
          # the number of backedges:
          #    back_preds(w).size()
          #
          # whether this loop is reducible:
          #    types(w) != BB_IRREDUCIBLE
          #
          nodes[w].l = l

          node_pool.each do |node|
            # Add nodes to loop descriptor.
            header[node.dfs_number] = w
            node.union(nodes[w])

            # Nested loops are not added, but linked together.
            if node_l = node.l
              node_l.parent = l
            else
              l.add_node(node.bb.not_nil!)
            end
          end

          @lsg.add_loop(l)
        end
      end
    end

    @lsg.num_loops
  end
end

def build_diamond(start)
  bb0 = start
  BasicBlockEdge.add(TOP_CFG, bb0, bb0 + 1)
  BasicBlockEdge.add(TOP_CFG, bb0, bb0 + 2)
  BasicBlockEdge.add(TOP_CFG, bb0 + 1, bb0 + 3)
  BasicBlockEdge.add(TOP_CFG, bb0 + 2, bb0 + 3)
  bb0 + 3
end

def build_connect(_start, _end)
  BasicBlockEdge.add(TOP_CFG, _start, _end)
end

def build_straight(start, n)
  n.times do |i|
    build_connect(start + i, start + i + 1)
  end
  start + n
end

def build_base_loop(from)
  header = build_straight(from, 1)
  diamond1 = build_diamond(header)
  d11 = build_straight(diamond1, 1)
  diamond2 = build_diamond(d11)
  footer = build_straight(diamond2, 1)
  build_connect(diamond2, d11)
  build_connect(diamond1, header)

  build_connect(footer, from)
  build_straight(footer, 1)
end

TOP_CFG = CFG.new

puts "Welcome to LoopTesterApp, Crystal edition"

puts "Constructing Simple CFG..."

TOP_CFG.create_node(0) # top
build_base_loop(0)
TOP_CFG.create_node(1) # bottom
build_connect(0, 2)

# execute loop recognition 15000 times to force compilation
puts "15000 dummy loops"
15000.times do
  HavlakLoopFinder.new(TOP_CFG, LSG.new).find_loops
end

puts "Constructing CFG..."
n = 2

10.times do |parlooptrees|
  TOP_CFG.create_node(n + 1)
  build_connect(2, n + 1)
  n = n + 1
  100.times do |i|
    top = n
    n = build_straight(n, 1)
    25.times { n = build_base_loop(n) }

    bottom = build_straight(n, 1)
    build_connect(n, top)
    n = bottom
  end

  build_connect(n, 1)
end

puts "Performing Loop Recognition\n1 Iteration"
loops = HavlakLoopFinder.new(TOP_CFG, LSG.new).find_loops

puts "Another 50 iterations..."

sum = 0
50.times do |i|
  print "."
  sum += HavlakLoopFinder.new(TOP_CFG, LSG.new).find_loops
end

puts "\nFound #{loops} loops (including artificial root node) (#{sum})\n"
