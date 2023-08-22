require "../syntax/ast"
require "../compiler"
require "json"

module Crystal
  class UnreachableResult
    include JSON::Serializable

    getter status : String
    getter message : String
    property locations : Array(Location)?

    def initialize(@status, @message)
    end

    def to_text(io)
      io.puts message
      locations.try do |arr|
        arr.each do |loc|
          io.puts loc
        end
      end
    end
  end

  class UnreachableVisitor < Visitor
    # object_id of used defs, extracted from DefInstanceKey of typed_defs
    @def_object_ids = Set(UInt64).new
    @locations = [] of Location

    def initialize(@filename : String)
    end

    def process_type(type)
      if type.is_a?(NamedType)
        type.types?.try &.values.each do |inner_type|
          process_type(inner_type)
        end
      end

      return unless type.is_a?(DefInstanceContainer)
      return unless type.is_a?(ModuleType)
      track_used_defs type
      track_unused_defs type
    end

    def process(result : Compiler::Result)
      res = UnreachableResult.new "TODO", "TODO"
      res.locations = @locations

      @def_object_ids.clear
      @locations.clear
      track_used_defs result.program
      track_unused_defs result.program

      result.program.types?.try &.values.each do |type|
        process_type type
        if metaclass = type.metaclass
          process_type metaclass
        end
      end

      # result.node.accept(self)

      # if @locations.empty?
      #   return ImplementationResult.new("failed", "no implementations or method call found")
      # else
      #   res = ImplementationResult.new("ok", "#{@locations.size} implementation#{@locations.size > 1 ? "s" : ""} found")
      #   res.implementations = @locations.map { |loc| LocationTrace.build(loc) }
      #   return res
      # end
      res
    end

    private def track_used_defs(container : DefInstanceContainer)
      container.def_instances.each_key do |def_instance_key|
        @def_object_ids << def_instance_key.def_object_id
      end
    end

    private def track_unused_defs(module_type : ModuleType)
      module_type.defs.try &.each_value.each do |defs_with_meta|
        defs_with_meta.each do |def_with_meta|
          next if def_with_meta.yields
          if interested_in(def_with_meta.def.location) && !@def_object_ids.includes?(def_with_meta.def.object_id)
            @locations << def_with_meta.def.location.not_nil!
          end
        end
      end
    end

    private def interested_in(location)
      (loc_filename = location.try &.filename) && loc_filename.is_a?(String) && loc_filename.starts_with?(@filename)
    end
  end
end
