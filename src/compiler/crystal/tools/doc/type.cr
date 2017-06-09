require "./item"

class Crystal::Doc::Type
  include Item

  getter type : Crystal::Type

  def initialize(@generator : Generator, @type : Crystal::Type)
  end

  def kind
    case @type
    when Const
      :const
    when .struct?
      :struct
    when .class?, .metaclass?
      :class
    when .module?
      :module
    when AliasType
      :alias
    when EnumType
      :enum
    when NoReturnType, VoidType
      :struct
    else
      raise "Unhandled type in `kind`: #{@type}"
    end
  end

  def name
    case type = @type
    when Program
      "Top Level Namespace"
    when NamedType
      type.name
    when NoReturnType
      "NoReturn"
    when VoidType
      "Void"
    when Const
      type.name
    when GenericInstanceType
      type.generic_type.name
    when TypeParameter
      type.name
    when TypeSplat
      "*#{type.splatted_type}"
    else
      raise "Unhandled type in `name`: #{@type}"
    end
  end

  def type_vars
    case type = @type
    when GenericType
      type.type_vars
    else
      nil
    end
  end

  def abstract?
    @type.abstract?
  end

  def parents_of?(type)
    return false unless type

    while type = type.namespace
      return true if type.full_name == full_name
    end

    false
  end

  def current?(type)
    return false unless type

    parents_of?(type) || type.full_name == full_name
  end

  def superclass
    case type = @type
    when ClassType
      superclass = type.superclass
    when GenericClassInstanceType
      superclass = type.superclass
    end

    if superclass
      @generator.type(superclass)
    else
      nil
    end
  end

  def ancestors
    ancestors = [] of self
    @type.ancestors.each do |ancestor|
      ancestors << @generator.type(ancestor)
      break if ancestor == @generator.program.object
    end
    ancestors
  end

  def locations
    @generator.relative_locations(@type)
  end

  def repository_name
    @generator.repository_name
  end

  def program?
    @type.is_a?(Program)
  end

  def program
    @generator.type(@type.program)
  end

  def enum?
    kind == :enum
  end

  def alias?
    kind == :alias
  end

  def const?
    kind == :const
  end

  def alias_definition
    alias_def = @type.as(AliasType).aliased_type
    alias_def
  end

  def formatted_alias_definition
    type_to_html alias_definition
  end

  @types : Array(Type)?

  def types
    @types ||= @generator.collect_subtypes(@type)
  end

  @instance_methods : Array(Method)?

  def instance_methods
    @instance_methods ||= begin
      case @type
      when Program
        [] of Method
      else
        defs = [] of Method
        @type.defs.try &.each do |def_name, defs_with_metadata|
          defs_with_metadata.each do |def_with_metadata|
            case def_with_metadata.def.visibility
            when .private?, .protected?
              next
            end

            if @generator.must_include? def_with_metadata.def
              defs << method(def_with_metadata.def, false)
            end
          end
        end
        defs.sort_by! &.name.downcase
      end
    end
  end

  @class_methods : Array(Method)?

  def all_class_methods
    @class_methods ||= begin
      class_methods = [] of Method
      @type.metaclass.defs.try &.each_value do |defs_with_metadata|
        defs_with_metadata.each do |def_with_metadata|
          a_def = def_with_metadata.def
          case a_def.visibility
          when .private?, .protected?
            next
          end

          body = a_def.body

          # Skip auto-generated allocate method
          if body.is_a?(Crystal::Primitive) && body.name == "allocate"
            next
          end

          if @generator.must_include? a_def
            class_methods << method(a_def, true)
          end
        end
      end
      class_methods.sort_by! &.name.downcase
    end
  end

  def class_methods
    all_class_methods - constructors
  end

  def constructors
    all_class_methods.select &.constructor?
  end

  @macros : Array(Macro)?

  def macros
    @macros ||= begin
      macros = [] of Macro
      @type.metaclass.macros.try &.each_value do |the_macros|
        the_macros.each do |a_macro|
          if a_macro.visibility.public? && @generator.must_include? a_macro
            macros << self.macro(a_macro)
          end
        end
      end
      macros.sort_by! &.name.downcase
    end
  end

  @constants : Array(Constant)?

  def constants
    @constants ||= @generator.collect_constants(self)
  end

  @included_modules : Array(Type)?

  def included_modules
    @included_modules ||= begin
      included_modules = [] of Type
      @type.parents.try &.each do |parent|
        if parent.module?
          included_modules << @generator.type(parent)
        end
      end
      included_modules.sort_by! &.full_name.downcase
    end
  end

  @extended_modules : Array(Type)?

  def extended_modules
    @extended_modules ||= begin
      extended_modules = [] of Type
      @type.metaclass.parents.try &.each do |parent|
        if parent.module?
          extended_modules << @generator.type(parent)
        end
      end
      extended_modules.sort_by! &.full_name.downcase
    end
  end

  @subclasses : Array(Type)?

  def subclasses
    @subclasses ||= begin
      case type = @type
      when .metaclass?
        [] of Type
      when ClassType
        subclasses = [] of Type
        type.subclasses.each do |subclass|
          case subclass
          when GenericClassInstanceType
            next
          when NonGenericClassType
            next if subclass.extern?
          end

          next unless @generator.must_include?(subclass)

          subclasses << @generator.type(subclass)
        end
        subclasses.sort_by! &.full_name.downcase
      else
        [] of Type
      end
    end
  end

  @including_types : Array(Type)?

  def including_types
    @including_types ||= begin
      case type = @type
      when NonGenericModuleType
        gather_including_types type
      when GenericModuleType
        gather_including_types type
      else
        [] of Type
      end
    end
  end

  private def gather_including_types(type)
    including_types = [] of Type
    type.raw_including_types.try &.each do |subtype|
      if @generator.must_include? subtype
        including_types << @generator.type(subtype)
      end
    end
    including_types.uniq!.sort_by! &.full_name.downcase
  end

  def namespace
    namespace = type.namespace
    if namespace.is_a?(Program)
      nil
    else
      @generator.type(namespace)
    end
  end

  def full_name
    String.build { |io| full_name(io) }
  end

  def full_name(io)
    full_name_without_type_vars(io)
    append_type_vars io
  end

  def full_name_without_type_vars
    String.build { |io| full_name_without_type_vars(io) }
  end

  def full_name_without_type_vars(io)
    if namespace = self.namespace
      namespace.full_name_without_type_vars(io)
      io << "::"
    end
    io << name
  end

  def path
    if program?
      "toplevel.html"
    elsif namespace = self.namespace
      "#{namespace.dir}/#{name}.html"
    else
      "#{name}.html"
    end
  end

  def path_from(type)
    if type
      type.path_to(self)
    else
      path
    end
  end

  def path_to(filename : String)
    "#{"../" * nesting}#{filename}"
  end

  def path_to(type : Type)
    if type.const?
      namespace = type.namespace || @generator.program_type
      "#{path_to(namespace)}##{type.name}"
    else
      path_to(type.path)
    end
  end

  def link_from(type : Type)
    type.type_to_html self
  end

  def dir
    if namespace = self.namespace
      "#{namespace.dir}/#{name}"
    else
      name.to_s
    end
  end

  def nesting
    if namespace = self.namespace
      1 + namespace.nesting
    else
      0
    end
  end

  def doc
    @type.doc
  end

  def lookup_path(path_or_names : Path | Array(String))
    match = @type.lookup_path(path_or_names)
    return unless match.is_a?(Crystal::Type)

    @generator.type(match)
  end

  def lookup_path(full_path : String)
    global = full_path.starts_with?("::")
    full_path = full_path[2..-1] if global
    path = Path.new(full_path.split("::"), global: global)
    lookup_path(path)
  end

  def lookup_method(name)
    lookup_in_methods instance_methods, name
  end

  def lookup_method(name, args_size)
    lookup_in_methods instance_methods, name, args_size
  end

  def lookup_class_method(name)
    lookup_in_methods class_methods, name
  end

  def lookup_class_method(name, args_size)
    lookup_in_methods class_methods, name, args_size
  end

  def lookup_macro(name)
    lookup_in_methods macros, name
  end

  def lookup_macro(name, args_size)
    lookup_in_methods macros, name, args_size
  end

  private def lookup_in_methods(methods, name)
    methods.find { |method| method.name == name }
  end

  private def lookup_in_methods(methods, name, args_size)
    if args_size
      methods.find { |method| method.name == name && method.args.size == args_size }
    else
      methods = methods.select { |method| method.name == name }
      (methods.find { |method| method.args.empty? }) || methods.first?
    end
  end

  def method(a_def, class_method)
    @generator.method(self, a_def, class_method)
  end

  def macro(a_macro)
    @generator.macro(self, a_macro)
  end

  def to_s(io)
    io << name
    append_type_vars io
  end

  private def append_type_vars(io)
    type = @type
    if type_vars = type_vars()
      io << '('
      io << "**" if type.is_a?(GenericType) && type.double_variadic?
      type_vars.each_with_index do |type_var, i|
        io << ", " if i > 0
        io << '*' if type.is_a?(GenericType) && type.splat_index == i
        io << type_var
      end
      io << ')'
    end
  end

  def node_to_html(node)
    String.build { |io| node_to_html node, io }
  end

  def node_to_html(node : Path, io, links = true)
    match = lookup_path(node)
    if match
      # If the path is global, search a local path and
      # see if there's a different match. If not, we can safely
      # remove the `::` as a prefix (harder to read)
      remove_colons = false
      if node.global?
        node.global = false
        remove_colons = lookup_path(node) == match
        node.global = true unless remove_colons
      end

      type_to_html match, io, node.to_s, links: links
      node.global = true if remove_colons
    else
      io << node
    end
  end

  def node_to_html(node : Generic, io, links = true)
    match = lookup_path(node.name)
    if match
      if match.must_be_included?
        if links
          io << %(<a href=")
          io << match.path_from(self)
          io << %(">)
        end
        match.full_name_without_type_vars(io)
        if links
          io << "</a>"
        end
      else
        io << node.name
      end
    else
      io << node.name
    end
    io << "("
    node.type_vars.join(", ", io) do |type_var|
      node_to_html type_var, io, links: links
    end
    io << ")"
  end

  def node_to_html(node : ProcNotation, io, links = true)
    if inputs = node.inputs
      inputs.join(", ", io) do |input|
        node_to_html input, io, links: links
      end
    end
    io << " -> "
    if output = node.output
      node_to_html output, io, links: links
    end
  end

  def node_to_html(node : Union, io, links = true)
    # See if it's a nilable type
    if node.types.size == 2
      # See if first type is Nil
      if nil_type?(node.types[0])
        return nilable_type_to_html node.types[1], io, links: links
      elsif nil_type?(node.types[1])
        return nilable_type_to_html node.types[0], io, links: links
      end
    end

    node.types.join(" | ", io) do |elem|
      node_to_html elem, io, links: links
    end
  end

  private def nilable_type_to_html(node : ASTNode, io, links)
    node_to_html node, io, links: links
    io << "?"
  end

  private def nilable_type_to_html(type : Crystal::Type, io, text, links)
    type_to_html(type, io, text, links: links)
    io << "?"
  end

  def nil_type?(node : ASTNode)
    return false unless node.is_a?(Path)

    match = lookup_path(node)
    match && match.type == @generator.program.nil_type
  end

  def node_to_html(node, io, links = true)
    io << node
  end

  def type_to_html(type)
    type = type.type if type.is_a?(Type)
    String.build { |io| type_to_html(type, io) }
  end

  def type_to_html(type : Crystal::UnionType, io, text = nil, links = true)
    has_type_splat = type.union_types.any? &.is_a?(TypeSplat)

    if !has_type_splat && type.union_types.size == 2
      if type.union_types[0].nil_type?
        return nilable_type_to_html(type.union_types[1], io, text, links)
      elsif type.union_types[1].nil_type?
        return nilable_type_to_html(type.union_types[0], io, text, links)
      end
    end

    if has_type_splat
      io << "Union("
      separator = ", "
    else
      separator = " | "
    end

    type.union_types.join(separator, io) do |union_type|
      type_to_html union_type, io, text, links: links
    end

    io << ")" if has_type_splat
  end

  def type_to_html(type : Crystal::ProcInstanceType, io, text = nil, links = true)
    type.arg_types.join(", ", io) do |arg_type|
      type_to_html arg_type, io, links: links
    end
    io << " -> "
    return_type = type.return_type
    type_to_html return_type, io, links: links unless return_type.void?
  end

  def type_to_html(type : Crystal::TupleInstanceType, io, text = nil, links = true)
    io << "{"
    type.tuple_types.join(", ", io) do |tuple_type|
      type_to_html tuple_type, io, links: links
    end
    io << "}"
  end

  def type_to_html(type : Crystal::NamedTupleInstanceType, io, text = nil, links = true)
    io << "{"
    type.entries.join(", ", io) do |entry|
      if Symbol.needs_quotes?(entry.name)
        entry.name.inspect(io)
      else
        io << entry.name
      end
      io << ": "
      type_to_html entry.type, io, links: links
    end
    io << "}"
  end

  def type_to_html(type : Crystal::GenericInstanceType, io, text = nil, links = true)
    has_link_in_type_vars = type.type_vars.any? { |(name, type_var)| type_has_link? type_var.as?(Var).try(&.type) || type_var }
    generic_type = @generator.type(type.generic_type)
    must_be_included = generic_type.must_be_included?

    if must_be_included && links
      io << %(<a href=")
      io << generic_type.path_from(self)
      io << %(">)
    end

    if text
      io << text
    else
      generic_type.full_name_without_type_vars(io)
    end

    io << "</a>" if must_be_included && links && has_link_in_type_vars

    io << '('
    type.type_vars.values.join(", ", io) do |type_var|
      case type_var
      when Var
        type_to_html type_var.type, io, links: links
      else
        type_to_html type_var, io, links: links
      end
    end
    io << ')'

    io << "</a>" if must_be_included && links && !has_link_in_type_vars
  end

  def type_to_html(type : Crystal::VirtualType, io, text = nil, links = true)
    type_to_html type.base_type, io, text, links: links
  end

  def type_to_html(type : Crystal::Type, io, text = nil, links = true)
    type = @generator.type(type)
    if type.must_be_included?
      if links
        io << %(<a href=")
        io << type.path_from(self)
        io << %(">)
      end
      if text
        io << text
      else
        type.full_name(io)
      end
      if links
        io << "</a>"
      end
    else
      if text
        io << text
      else
        type.full_name(io)
      end
    end
  end

  def type_to_html(type : Type, io, text = nil, links = true)
    type_to_html type.type, io, text, links: links
  end

  def type_to_html(type : ASTNode, io, text = nil, links = true)
    type.to_s io
  end

  def type_has_link?(type : Crystal::UnionType)
    type.union_types.any? { |type| type_has_link? type }
  end

  def type_has_link?(type : Crystal::ProcInstanceType)
    type.arg_types.any? { |type| type_has_link? type } ||
      type_has_link? type.return_type
  end

  def type_has_link?(type : Crystal::TupleInstanceType)
    type.tuple_types.any? { |type| type_has_link? type }
  end

  def type_has_link?(type : Crystal::NamedTupleInstanceType)
    type.entries.any? { |entry| type_has_link? entry.type }
  end

  def type_has_link?(type : Crystal::GenericInstanceType)
    @generator.type(type.generic_type).must_be_included? ||
      type.type_vars.any? { |(name, type_var)| type_has_link? type_var.as?(Var).try(&.type) || type_var }
  end

  def type_has_link?(type : Crystal::Type)
    @generator.type(type.devirtualize).must_be_included?
  end

  def type_has_link?(type : Crystal::TypeParameter | ASTNode)
    false
  end

  def must_be_included?
    @generator.must_include? self
  end

  def superclass_hierarchy
    hierarchy = [self]
    superclass = self.superclass
    while superclass
      hierarchy << superclass
      superclass = superclass.superclass
    end
    String.build do |io|
      io << %(<ul class="superclass-hierarchy">)
      hierarchy.each do |type|
        io << %(<li class="superclass">)
        type_to_html type, io
        io << "</li>"
      end
      io << "</ul>"
    end
  end

  def html_id
    "#{@generator.repository_name}/" + (
      if program?
        "toplevel"
      elsif namespace = self.namespace
        "#{namespace.dir}/#{name}"
      else
        "#{name}"
      end
    )
  end

  delegate to_s, inspect, to: @type
end
