# Havlak benchmark: https://code.google.com/p/multi-language-bench/
# Crystal Implementation (translated from Python version)

# Intel i5 2.5GHz
# c++:     27.8s 147Mb
# java:    31.5s 909Mb
# crystal: 35.3s 409Mb
# scala:   66.8s 316Mb
# go:      67.7s 456Mb
# python:  958.4s 713Mb

class BasicBlock
  def initialize(@name)
    @inEdges  = [] of BasicBlock
    @outEdges = [] of BasicBlock
  end

  property :inEdges
  property :outEdges

  def to_s
    "BB##{@name}"
  end
end

struct BasicBlockEdge
  def initialize(cfg, fromName, toName)
    @from = cfg.createNode(fromName)
    @to   = cfg.createNode(toName)
    @from.outEdges << @to
    @to.inEdges << @from
  end

  def self.add(cfg, fromName, toName)
    edge = new(cfg, fromName, toName)
    cfg.addEdge(edge)
  end
end

class CFG
  def initialize
    @basicBlockMap = {} of Int32 => BasicBlock
    @edgeList      = [] of BasicBlockEdge
  end
  
  property :startNode
  property :basicBlockMap

  def createNode(name)
    node = (@basicBlockMap[name] ||= BasicBlock.new(name))
    @startNode ||= node
    node
  end

  def addEdge(edge)
    @edgeList << edge
  end

  def getNumNodes
    @basicBlockMap.length
  end
end

class SimpleLoop
  def initialize
    @basicBlocks  = Set(BasicBlock).new
    @children     = Set(SimpleLoop).new
    @parent       = nil
    @header       = nil

    @isRoot       = false
    @isReducible  = true
    @counter      = 0
    @nestingLevel = 0
    @depthLevel   = 0
  end

  property :counter
  property :isReducible
  property :isRoot
  property :parent
  property :depthLevel
  property :children
  property :nestingLevel

  def addNode(bb)
    @basicBlocks.add(bb)
  end

  def addChildLoop(l)
    @children.add(l)
  end

  def setParent(parent)
    @parent = parent
    parent.addChildLoop(self)
  end

  def setHeader(bb)
    @basicBlocks.add(bb)
    @header = bb
  end

  def setNestingLevel(level)
    @nestingLevel = level
    @isRoot = true if level == 0
  end
end

$loopCounter = 0

class LSG
  def initialize
    @loops = [] of SimpleLoop
    @root  = createNewLoop
    @root.setNestingLevel(0)
    addLoop(@root)
  end

  def createNewLoop
    s = SimpleLoop.new
    s.counter = $loopCounter += 1
    s
  end

  def addLoop(l)
    @loops << l
  end

  def calculateNestingLevel
    @loops.each do |liter|
      liter.setParent(@root) if !liter.isRoot && liter.parent == nil
    end

    calculateNestingLevelRec(@root, 0)
  end

  def calculateNestingLevelRec(l, depth)
    l.depthLevel = depth
    l.children.each do |liter|
      calculateNestingLevelRec(liter, depth + 1)
      l.setNestingLevel(Math.max(l.nestingLevel, 1 + liter.nestingLevel))
    end
  end

  def getNumLoops
    @loops.size
  end
end

class UnionFindNode
  def initialize
    @parent    = nil
    @bb        = nil
    @l         = nil
    @dfsNumber = 0
  end

  def initNode(bb, dfsNumber)
    @parent     = self
    @bb         = bb
    @dfsNumber  = dfsNumber
  end

  property :bb
  property :parent
  property :dfsNumber
  property :l

  def findSet
    nodeList = [] of UnionFindNode

    node = self
    while node != node.parent
      nodeList << node if node.parent != node.parent.not_nil!.parent
      node = node.parent.not_nil!
    end

    nodeList.each { |iter| iter.parent = node.parent }

    node
  end

  def union(unionFindNode)
    @parent = unionFindNode
  end
end

class HavlakLoopFinder
  BB_TOP          = 0 # uninitialized
  BB_NONHEADER    = 1 # a regular BB
  BB_REDUCIBLE    = 2 # reducible loop
  BB_SELF         = 3 # single BB loop
  BB_IRREDUCIBLE  = 4 # irreducible loop
  BB_DEAD         = 5 # a dead BB
  BB_LAST         = 6 # Sentinel

  # Marker for uninitialized nodes.
  UNVISITED = -1

  # Safeguard against pathologic algorithm behavior.
  MAXNONBACKPREDS = (32 * 1024)

  def initialize(@cfg, @lsg)
  end

  def isAncestor(w, v, last)
    w <= v <= last[w]
  end

  def dfs(currentNode, nodes, number, last, current)
    nodes[current].initNode(currentNode, current)
    number[currentNode] = current

    lastid = current
    currentNode.outEdges.each do |target|
      if number[target] == UNVISITED
        lastid = dfs(target, nodes, number, last, lastid + 1)
      end
    end

    last[number[currentNode]] = lastid
    lastid
  end

  def findLoops
    return 0 unless @cfg.startNode
    size = @cfg.getNumNodes

    nonBackPreds    = Array(Set(Int32)).new(size) { Set(Int32).new }
    backPreds       = Array(Array(Int32)).new(size) { Array(Int32).new }
    number          = {} of BasicBlock => Int32
    header          = Array(Int32).new(size, 0)
    types           = Array(Int32).new(size, 0)
    last            = Array(Int32).new(size, 0)
    nodes           = Array(UnionFindNode).new(size) { UnionFindNode.new }

    # Step a:
    #   - initialize all nodes as unvisited.
    #   - depth-first traversal and numbering.
    #   - unreached BB's are marked as dead.
    #
    @cfg.basicBlockMap.each_value { |v| number[v] = UNVISITED }
    dfs(@cfg.startNode.not_nil!, nodes, number, last, 0)

    # Step b:
    #   - iterate over all nodes.
    #
    #   A backedge comes from a descendant in the DFS tree, and non-backedges
    #   from non-descendants (following Tarjan).
    #
    #   - check incoming edges 'v' and add them to either
    #     - the list of backedges (backPreds) or
    #     - the list of non-backedges (nonBackPreds)
    #
    size.times do |w|
      header[w] = 0
      types[w]  = BB_NONHEADER

      nodeW = nodes[w].bb
      if nodeW
        nodeW.inEdges.each do |nodeV|
          v = number[nodeV]
          if v != UNVISITED
            if isAncestor(w, v, last)
              backPreds[w] << v
            else
              nonBackPreds[w].add(v)
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
      nodePool = [] of UnionFindNode

      nodeW = nodes[w].bb
      if nodeW # dead BB

        # Step d:
        backPreds[w].each do |v|
          if v != w
            nodePool << nodes[v].findSet
          else
            types[w] = BB_SELF
          end
        end

        # Copy nodePool to workList.
        #
        workList = nodePool.dup

        types[w] = BB_REDUCIBLE if nodePool.size != 0

        # work the list...
        #
        while !workList.empty?
          x = workList.shift

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
          nonBackSize = nonBackPreds[x.dfsNumber].length
          return 0 if nonBackSize > MAXNONBACKPREDS

          nonBackPreds[x.dfsNumber].each do |iter|
            y = nodes[iter]
            ydash = y.findSet

            if !isAncestor(w, ydash.dfsNumber, last)
              types[w] = BB_IRREDUCIBLE
              nonBackPreds[w].add(ydash.dfsNumber)
            else
              if ydash.dfsNumber != w && !nodePool.includes?(ydash)
                workList << ydash
                nodePool << ydash
              end
            end
          end
        end

        # Collapse/Unionize nodes in a SCC to a single node
        # For every SCC found, create a loop descriptor and link it in.
        #
        if (nodePool.size > 0) || (types[w] == BB_SELF)
          l = @lsg.createNewLoop

          l.setHeader(nodeW)
          l.isReducible = types[w] != BB_IRREDUCIBLE

          # At this point, one can set attributes to the loop, such as:
          #
          # the bottom node:
          #    iter  = backPreds(w).begin();
          #    loop bottom is: nodes(iter).node;
          #
          # the number of backedges:
          #    backPreds(w).size()
          #
          # whether this loop is reducible:
          #    types(w) != BB_IRREDUCIBLE
          #
          nodes[w].l = l

          nodePool.each do |node|
            # Add nodes to loop descriptor.
            header[node.dfsNumber] = w
            node.union(nodes[w])

            # Nested loops are not added, but linked together.
            if node_l = node.l
              node_l.setParent(l)
            else
              l.addNode(node.bb.not_nil!)
            end
          end

          @lsg.addLoop(l)
        end
      end
    end

    @lsg.getNumLoops
  end
end

def buildDiamond(start)
  bb0 = start
  BasicBlockEdge.add($cfg, bb0, bb0 + 1)
  BasicBlockEdge.add($cfg, bb0, bb0 + 2)
  BasicBlockEdge.add($cfg, bb0 + 1, bb0 + 3)
  BasicBlockEdge.add($cfg, bb0 + 2, bb0 + 3)
  bb0 + 3
end

def buildConnect(_start, _end)
  BasicBlockEdge.add($cfg, _start, _end)
end

def buildStraight(start, n)
  n.times do |i|
    buildConnect(start + i, start + i + 1)
  end
  start + n
end

def buildBaseLoop(from)
  header   = buildStraight(from, 1)
  diamond1 = buildDiamond(header)
  d11      = buildStraight(diamond1, 1)
  diamond2 = buildDiamond(d11)
  footer   = buildStraight(diamond2, 1)
  buildConnect(diamond2, d11)
  buildConnect(diamond1, header)

  buildConnect(footer, from)
  buildStraight(footer, 1)
end


$cfg = CFG.new

puts "Welcome to LoopTesterApp, Crystal edition"

puts "Constructing Simple CFG..."

$cfg.createNode(0)  # top
buildBaseLoop(0)
$cfg.createNode(1)  # bottom
buildConnect(0, 2)

# execute loop recognition 15000 times to force compilation
puts "15000 dummy loops"
15000.times do 
  HavlakLoopFinder.new($cfg, LSG.new).findLoops
end

puts "Constructing CFG..."
n = 2

10.times do |parlooptrees|
  $cfg.createNode(n + 1)
  buildConnect(2, n + 1)
  n = n + 1
  100.times do |i|
    top = n
    n = buildStraight(n, 1)
    25.times { n = buildBaseLoop(n) }

    bottom = buildStraight(n, 1)
    buildConnect(n, top)
    n = bottom
  end

  buildConnect(n, 1)
end

puts "Performing Loop Recognition\n1 Iteration"
lsg = LSG.new
loops = HavlakLoopFinder.new($cfg, lsg).findLoops

puts "Another 50 iterations..."

sum = 0
50.times do |i|
  print "."
  sum += HavlakLoopFinder.new($cfg, LSG.new).findLoops
end

puts "\nFound #{loops} loops (including artificial root node) (#{sum})\n"

