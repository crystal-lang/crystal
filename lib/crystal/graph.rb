require 'graphviz'

module Crystal
  def graph(node, mod, output = nil)
    output ||= 'crystal'

    visitor = GraphVisitor.new
    node.accept visitor

    visitor.graphviz.output :png => "#{output}.png"
  end

  class GraphVisitor < Visitor
    def initialize
      @g = GraphViz.new(:G, :type => :digraph, :rankdir => 'LR')
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
        var = @g.add_nodes node.name, :shape => :note
        @g.add_edges var, type_node(node.type)
        @vars << node.name
      end
    end

    def type_node(type)
      node = @g.get_node(type.object_id.to_s)
      unless node
        if type.is_a? ObjectType
          node = @g.add_nodes type.object_id.to_s, :shape => 'record', :label => type.name
          type.instance_vars.each do |ivar, type|
            @g.add_edges node, type_node(type), :label => ivar
          end
        else
          node = @g.add_nodes type.object_id.to_s, :label => type.name
        end
      end
      node
    end
  end
end