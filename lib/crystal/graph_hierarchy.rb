require 'graphviz'

module Crystal
  def graph_hierarchy(mod, output = nil)
    output ||= 'crystal'
    output = "#{output}_hierarchy.png"

    printer = GraphHierarchyPrinter.new mod
    printer.graphviz.output :png => output

    if RUBY_PLATFORM =~ /darwin/
      `open #{output} &`
    end
  end

  class GraphHierarchyPrinter
    def initialize(mod)
      @mod = mod
      @g = GraphViz.new(:G, :type => :graph, :rankdir => 'TB')
      @types = {}
    end

    def graphviz
      @mod.types.values.each do |type|
        graph_type type
      end
      @g
    end

    def graph_type(type)
      unless type.is_a?(LibType) || type.is_a?(Const) || type.module?
        node = @types[type.type_id]
        return node if node

        node = @g.add_nodes type.type_id.to_s, :label => graph_label(type), :shape => :record
        @types[type.type_id] = node

        if type.respond_to?(:superclass) && type.superclass
          superclass_node = graph_type type.superclass
          @g.add_edges superclass_node, node, :style => 'solid'
        end

        if type.is_a?(GenericType)
          type.generic_types.values.each do |instance|
            instance_node = graph_type instance
            @g.add_edges node, instance_node, :style => 'solid'
          end
        end
      end

      if !type.is_a?(LibType) && type.is_a?(ContainedType) && type.types
        type.types.each do |name, subtype|
          graph_type subtype if subtype
        end
      end

      node
    end

    def graph_label(type)
      str = "{ #{type} "
      if type.is_a?(InstanceVarContainer)
        all_ivars = type.all_instance_vars
        unless all_ivars.empty?
          str << " |"
          str << type.all_instance_vars.values.map { |var| "#{var.name} : #{var.type.to_s.gsub "|", "\\|"}" }.join(" | ")
        end
      end
      str << "}"
      str
    end
  end
end
