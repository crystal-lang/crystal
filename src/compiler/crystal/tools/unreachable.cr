require "../syntax/ast"
require "../compiler"
require "json"

module Crystal
  class Command
    private def unreachable
      config, result = compile_no_codegen "tool unreachable", path_filter: true
      format = config.output_format

      unreachable = UnreachableVisitor.new

      unreachable.includes.concat config.includes.map { |path| ::Path[path].expand.to_s }

      unreachable.excludes.concat CrystalPath.default_paths.map { |path| ::Path[path].expand.to_s }
      unreachable.excludes.concat config.excludes.map { |path| ::Path[path].expand.to_s }

      defs = unreachable.process(result)

      case format
      when "json"
        defs.to_json(STDOUT)
      else
        defs.to_text(STDOUT)
      end
    end
  end

  record UnreachableResult, defs : Array(Def) do
    include JSON::Serializable

    def to_text(io)
      defs.each do |a_def|
        io << a_def.location << "\t"
        io << a_def.short_reference << "\t"
        io << a_def.length << " lines"
        io.puts
      end
    end

    def to_json(builder : JSON::Builder)
      builder.array do
        defs.each do |a_def|
          builder.object do
            builder.field "name", a_def.short_reference
            builder.field "location", a_def.location
            if lines = a_def.length
              builder.field "lines", lines
            end
          end
        end
      end
    end
  end

  # Some defs (yielding, generic or virtual owner) are separate
  # instantiations and thus cannot be identified by a unique object_id. Thus
  # we're looking for location to identify the base def.
  class UnreachableVisitor < Visitor
    @used_def_locations = Set(Location).new
    @defs = [] of Def
    @visited_defs : Set(Def) = Set(Def).new.compare_by_identity

    property includes = [] of String
    property excludes = [] of String

    def process_type(type)
      if type.is_a?(ModuleType)
        track_unused_defs type
      end

      type.types?.try &.each_value do |inner_type|
        process_type(inner_type)
      end

      process_type(type.metaclass) if type.metaclass != type
    end

    def process(result : Compiler::Result)
      @defs.clear

      result.node.accept(self)

      process_type(result.program)

      UnreachableResult.new @defs
    end

    def visit(node)
      true
    end

    def visit(node : Call)
      node.target_defs.try &.each do |a_def|
        if (location = a_def.location)
          @used_def_locations << location if interested_in(location)
        end

        if @visited_defs.add?(a_def)
          a_def.body.accept(self)
        end
      end

      true
    end

    private def track_unused_defs(module_type : ModuleType)
      module_type.defs.try &.each_value.each do |defs_with_meta|
        defs_with_meta.each do |def_with_meta|
          check_def(def_with_meta.def)
        end
      end
    end

    private def check_def(a_def : Def)
      return if a_def.abstract?
      return unless interested_in(a_def.location)

      previous = a_def.previous.try(&.def)

      check_def(previous) if previous && !a_def.calls_previous_def?

      return if @used_def_locations.includes?(a_def.location)

      check_def(previous) if previous && a_def.calls_previous_def?

      @defs << a_def
    end

    private def interested_in(location)
      if filename = location.try(&.filename).as?(String)
        match_path?(filename)
      end
    end

    private def match_path?(path)
      paths = ::Path[path].parents << ::Path[path]

      match_any_pattern?(includes, paths) || !match_any_pattern?(excludes, paths)
    end

    private def match_any_pattern?(patterns, paths)
      patterns.any? { |pattern| paths.any? { |path| File.match?(pattern, path) } }
    end
  end
end
