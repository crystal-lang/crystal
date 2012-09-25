require 'graphviz'

module Crystal
  def graph(node, mod, output = 'crystal')
    visitor = GraphVisitor.new
    node.accept visitor

    visitor.graphviz.output :png => "#{output}.png"
    visitor.graphviz.to_s
  end

  class GraphVisitor < Visitor
    def initialize
      @g = GraphViz.new(:G, :type => :digraph)
      @vars = []
    end

    def graphviz
      @g
    end

    def visit_class_def(node)
      false
    end

    def visit_def(node)
      false
    end

    def visit_var(node)
      unless @vars.include? node.name
        var = @g.add_nodes node.name
        @g.add_edges var, type_node(node.type)
        @vars << node.name
      end
    end

    def type_node(type)
      node = @g.get_node(type.object_id.to_s)
      unless node
        node = @g.add_nodes type.object_id.to_s, :label => type.name
        if type.is_a? ObjectType
          type.instance_vars.each do |ivar, type|
            @g.add_edges node, type_node(type), :label => ivar
          end
        end
      end
      node
    end
  end
end