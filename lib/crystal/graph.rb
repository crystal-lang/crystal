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
        var = @g.add_nodes node.object_id.to_s, :label => node.name, :shape => :note
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
          add_object_type_edges node, type
        when nil
          node = @g.add_nodes type.object_id.to_s, :shape => :record, :label => 'nil'
        else
          node = @g.add_nodes type.object_id.to_s, :label => type.full_name
        end
      end
      node
    end

    def add_object_type_edges(node, type)
      if type.name == "String"
        # nothing
      elsif type.name == "Array"
        add_edges node, type.instance_vars["@buffer"].type.var.type
      elsif type.name == "Hash"
        entry_type = type.instance_vars["@first"] && type.instance_vars["@first"].type
        if entry_type.is_a?(UnionType)
          keys = Set.new
          values = Set.new
          entry_type.types.each do |t|
            next if t.name == "Nil"
            keys << t.instance_vars["@key"].type
            values << t.instance_vars["@value"].type
          end
          keys.each { |key| add_edges node, key, "key" }
          values.each { |value| add_edges node, value, "value" }
        end
      else
        type.instance_vars.each do |ivar, var|
          add_edges node, var.type, ivar
        end
      end
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
