require 'graphviz'

module Crystal
  def graph_hierarchy(mod, filter, output = nil)
    output ||= 'crystal'
    output = "#{output}_hierarchy.png"

    printer = GraphHierarchyPrinter.new mod, filter
    printer.graphviz.output :png => output

    if RUBY_PLATFORM =~ /darwin/
      `open #{output} &`
    end
  end

  class GraphHierarchyPrinter
    def initialize(mod, filter)
      @mod = mod
      @filter = filter.downcase
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
      return unless matches_filter?(type, @filter)

      unless type.is_a?(LibType) || type.is_a?(Const) || type.module?
        node = @types[type.type_id]
        return node if node

        node = @g.add_nodes type.type_id.to_s, :label => graph_label(type), :shape => :record
        @types[type.type_id] = node

        if type.respond_to?(:superclass) && type.superclass
          superclass_node = graph_type type.superclass
          @g.add_edges superclass_node, node, :style => 'solid' if superclass_node
        end

        if type.is_a?(GenericType)
          type.generic_types.values.each do |instance|
            instance_node = graph_type instance
            @g.add_edges node, instance_node, :style => 'solid' if instance_node
          end
        end
      end

      if !type.is_a?(LibType) && !type.is_a?(Const) && type.is_a?(ContainedType) && type.types
        type.types.values.each do |subtype|
          graph_type subtype
        end
      end

      node
    end

    def graph_label(type)
      str = "{ #{type} "
      if type.is_a?(InstanceVarContainer)
        all_ivars = type.instance_vars
        unless all_ivars.empty?
          str << " |"
          str << type.instance_vars.values.map { |var| "#{var.name} : #{var.type.to_s.gsub "|", "\\|"}" }.join(" | ")
        end
      end
      str << "}"
      str
    end

    def matches_filter?(type, filter, tested = {}, look_down = true)
      return false if tested[type.type_id]
      tested[type.type_id] = true

      if @filter.empty?
        true
      else
        return true if type.to_s.downcase.include?(filter)

        unless type.is_a?(LibType) || type.is_a?(Const) || type.module?
          if type.respond_to?(:superclass) && type.superclass
            return true if matches_filter?(type.superclass, filter, tested, false)
          end

          if look_down && type.respond_to?(:subclasses)
            return true if type.subclasses.any? { |subclass| matches_filter?(subclass, filter, tested) }
          end
        end

        if look_down && !type.is_a?(LibType) && !type.is_a?(Const) && type.is_a?(ContainedType) && type.types
          return true if type.types.values.any? { |subtype| matches_filter?(subtype, filter, tested) }
        end

        false
      end
    end
  end
end
