require "../syntax/ast"
require "../compiler"
require "json"
require "csv"

module Crystal
  class Command
    private def unreachable
      config, result = compile_no_codegen "tool unreachable", path_filter: true, unreachable_command: true, allowed_formats: %w[text json csv]

      unreachable = UnreachableVisitor.new

      unreachable.includes.concat config.includes.map { |path| ::Path[path].expand.to_posix.to_s }

      unreachable.excludes.concat CrystalPath.default_paths.map { |path| ::Path[path].expand.to_posix.to_s }
      unreachable.excludes.concat config.excludes.map { |path| ::Path[path].expand.to_posix.to_s }

      defs = unreachable.process(result)
      defs.sort_by! do |a_def|
        location = a_def.location.not_nil!
        {
          location.filename.as(String),
          location.line_number,
          location.column_number,
        }
      end

      UnreachablePresenter.new(defs, format: config.output_format).to_s(STDOUT)

      if config.check
        exit 1 unless defs.empty?
      end
    end
  end

  record UnreachablePresenter, defs : Array(Def), format : String? do
    include JSON::Serializable

    def to_s(io)
      case format
      when "json"
        to_json(STDOUT)
      when "csv"
        to_csv(STDOUT)
      else
        to_text(STDOUT)
      end
    end

    def each(&)
      current_dir = Dir.current
      defs.each do |a_def|
        location = a_def.location.not_nil!
        filename = ::Path[location.filename.as(String)].relative_to(current_dir).to_s
        location = Location.new(filename, location.line_number, location.column_number)
        yield a_def, location
      end
    end

    def to_text(io)
      each do |a_def, location|
        io << location << "\t"
        io << a_def.short_reference << "\t"
        io << a_def.length << " lines"
        if annotations = a_def.all_annotations
          io << "\t"
          annotations.join(io, " ")
        end
        io.puts
      end
    end

    def to_json(builder : JSON::Builder)
      builder.array do
        each do |a_def, location|
          builder.object do
            builder.field "name", a_def.short_reference
            builder.field "location", location.to_s
            if lines = a_def.length
              builder.field "lines", lines
            end
            if annotations = a_def.all_annotations
              builder.field "annotations", annotations.map(&.to_s)
            end
          end
        end
      end
    end

    def to_csv(io)
      CSV.build(io) do |builder|
        builder.row %w[name file line column length annotations]
        each do |a_def, location|
          builder.row do |row|
            row << a_def.short_reference
            row << location.filename
            row << location.line_number
            row << location.column_number
            row << a_def.length
            row << a_def.all_annotations.try(&.join(" "))
          end
        end
      end
    end
  end

  # This visitor walks the entire reachable code tree and collect locations
  # of all defs that are a target of a call into `@used_def_locations`.
  # The locations are filtered to only those that we're interested in per
  # `@includes` and `@excludes`.
  # Then it traverses all types and their defs and reports those that are not
  # in `@used_def_locations` (and match the filter).
  class UnreachableVisitor < Visitor
    @used_def_locations = Set(Location).new
    @defs : Set(Def) = Set(Def).new.compare_by_identity
    @visited : Set(ASTNode) = Set(ASTNode).new.compare_by_identity

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

    def process(result : Compiler::Result) : Array(Def)
      @defs.clear

      result.node.accept(self)

      process_type(result.program)

      @defs.to_a
    end

    def visit(node)
      true
    end

    def visit(node : ExpandableNode)
      return false unless @visited.add?(node)

      if expanded = node.expanded
        expanded.accept self
      end

      true
    end

    def visit(node : Call)
      if expanded = node.expanded
        expanded.accept(self)

        return true
      end

      node.target_defs.try &.each do |a_def|
        if (location = a_def.location)
          @used_def_locations << location if interested_in(location)
        end

        if @visited.add?(a_def)
          a_def.body.accept(self)
        end
      end

      true
    end

    def visit(node : ClassDef)
      node.resolved_type.instance_vars_initializers.try &.each do |initializer|
        initializer.value.accept(self)
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
      return if a_def.autogenerated?
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

    def match_path?(path)
      paths = ::Path[path].parents << ::Path[path]

      match_any_pattern?(includes, paths) || !match_any_pattern?(excludes, paths)
    end

    private def match_any_pattern?(patterns, paths)
      patterns.any? { |pattern| paths.any? { |path| path == pattern || File.match?(pattern, path.to_posix) } }
    end
  end
end
