require 'graphviz'
require_relative 'ast.rb'

module Crystal
  def graph(node, mod, output = nil)
    output ||= 'crystal'

    visitor = GraphVisitor.new
    node.accept visitor if node

    visitor.graphviz.output :png => "#{output}.png"

    `open #{output}.png &`
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
        add_edges var, node.type
        @vars << node.name
      end
    end

    def type_node(type)
      node = @g.get_node(type.object_id.to_s)
      unless node
        case type
        when ObjectType
          node = @g.add_nodes type.object_id.to_s, :shape => :record, :label => type.full_name
          type.instance_vars.each do |ivar, var|
            add_edges node, var.type, ivar
          end
        when nil
          node = @g.add_nodes type.object_id.to_s, :shape => :record, :label => 'Nil'
        else
          node = @g.add_nodes type.object_id.to_s, :label => type.full_name
        end
      end
      node
    end

    def add_edges(node, type, label = '', style = 'solid')
      if type.is_a?(UnionType)
        type.types.each { |t| add_edges node, t, label, style }
      elsif type.is_a?(PointerType)
        add_edges node, type.var.type, label, 'dashed'
      else
        @g.add_edges node, type_node(type), :label => label, :style => style
      end
    end
  end
end
