require 'graphviz'
require_relative 'ast.rb'

module Crystal
  def graph(node, mod, output = nil)
    output ||= 'crystal'

    visitor = GraphVisitor.new
    if node
      # Jump over the require "prelude" that's inserted by the compiler
      if node.is_a?(Expressions)
        node.expressions[1 .. -1].each do |exp|
          exp.accept visitor
        end
      else
        node.accept visitor
      end
    end

    visitor.graphviz.output :png => "#{output}.png"

    if RUBY_PLATFORM =~ /darwin/
      `open #{output}.png &`
    end
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

    def visit_macro(node)
      false
    end

    def visit_assign(node)
      !node.target.is_a?(Ident)
    end

    def visit_var(node)
      output_name node
    end

    def visit_declare_var(node)
      output_name node
    end

    def output_name(node)
      if !node.name.start_with?('#') && !@vars.include?(node.name)
        var = @g.add_nodes node.object_id.to_s, :label => node.name, :shape => :note
        add_edges var, node.type
        @vars << node.name
      end
    end

    def type_node(type)
      node = @g.get_node(type.type_id.to_s)
      unless node
        case type
        when PointerInstanceType
          node = @g.add_nodes type.type_id.to_s, :shape => :record, :label => type.to_s.gsub("|", "\\|")
          add_edges node, type.var.type, '', 'dashed'
        when NonGenericClassType, GenericClassInstanceType
          node = @g.add_nodes type.type_id.to_s, :shape => :record, :label => type.to_s.gsub("|", "\\|")
          add_object_type_edges node, type
        when nil
          node = @g.add_nodes type.type_id.to_s, :shape => :record, :label => 'nil'
        else
          node = @g.add_nodes type.type_id.to_s, :label => type.to_s
        end
      end
      node
    end

    def add_object_type_edges(node, type)
      type.each_instance_var do |ivar, var|
        add_edges node, var.type, ivar
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
