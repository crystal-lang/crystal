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
    when InheritedGenericClass
      :class
    when IncludedGenericModule
      :module
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
    when InheritedGenericClass
      type.extended_class.name
    when IncludedGenericModule
      type.module.name
    when Const
      type.name
    else
      raise "Unhandled type in `name`: #{@type}"
    end
  end

  def type_vars
    case type = @type
    when GenericType
      type.type_vars
    when InheritedGenericClass
      type_mapping_values type
    when IncludedGenericModule
      type_mapping_values type
    else
      nil
    end
  end

  def abstract?
    @type.abstract?
  end

  def parents_of?(type)
    return false unless type

    while type = type.container
      return true if type.full_name == full_name
    end

    false
  end

  def current?(type)
    return false unless type

    parents_of?(type) || type.full_name == full_name
  end

  private def type_mapping_values(type)
    values = type.mapping.values
    if values.any? &.is_a?(TypeOf)
      values = values.map do |value|
        value.is_a?(TypeOf) ? TypeOf.new([Var.new("...")] of ASTNode) : value
      end
    end
    values
  end

  def superclass
    case type = @type
    when ClassType
      superclass = type.superclass
    when InheritedGenericClass
      superclass = type.extended_class.superclass
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
      case ancestor
      when InheritedGenericClass
        ancestor = ancestor.extended_class
      when IncludedGenericModule
        ancestor = ancestor.module
      end
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
    alias_def = (@type as AliasType).aliased_type
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
      case type = @type
      when Program
        [] of Method
      when DefContainer
        defs = [] of Method
        type.defs.try &.each do |def_name, defs_with_metadata|
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
      else
        [] of Method
      end
    end
  end

  @class_methods : Array(Method)?

  def class_methods
    @class_methods ||= begin
      class_methods =
        case type = @type.metaclass
        when DefContainer
          defs = [] of Method
          type.defs.try &.each_value do |defs_with_metadata|
            defs_with_metadata.each do |def_with_metadata|
              a_def = def_with_metadata.def
              case a_def.visibility
              when .private?, .protected?
                next
              end

              body = a_def.body

              # Skip auto-generated allocate method
              if body.is_a?(Crystal::Primitive) && body.name == :allocate
                next
              end

              # Skip auto-generated new methods from initialize
              if a_def.name == "new" && !a_def.location
                next
              end

              if @generator.must_include? a_def
                defs << method(a_def, true)
              end
            end
          end
          defs.sort_by! &.name.downcase
        else
          [] of Method
        end

      # Also get `initialize` methods from instance type,
      # but show them as `new`
      case type = @type
      when DefContainer
        type.defs.try &.each_value do |defs_with_metadata|
          defs_with_metadata.each do |def_with_metadata|
            a_def = def_with_metadata.def
            if a_def.name == "initialize" && @generator.must_include?(a_def)
              initialize = a_def.clone
              initialize.doc = a_def.doc
              initialize.name = "new"
              class_methods << method(initialize, true)
            end
          end
        end
      end

      class_methods
    end
  end

  @macros : Array(Macro)?

  def macros
    @macros ||= begin
      case type = @type.metaclass
      when DefContainer
        macros = [] of Macro
        type.macros.try &.each_value do |the_macros|
          the_macros.each do |a_macro|
            if @generator.must_include? a_macro
              macros << self.macro(a_macro)
            end
          end
        end
        macros.sort_by! &.name.downcase
      else
        [] of Macro
      end
    end
  end

  @constants : Array(Constant)?

  def constants
    @constants ||= @generator.collect_constants(self)
  end

  @included_modules : Array(Type)?

  def included_modules
    @included_modules ||= begin
      parents = @type.parents || [] of Crystal::Type
      included_modules = [] of Type
      parents.each do |parent|
        if parent.module? || parent.is_a?(IncludedGenericModule)
          included_modules << @generator.type(parent)
        end
      end
      included_modules.sort_by! &.full_name.downcase
    end
  end

  @extended_modules : Array(Type)?

  def extended_modules
    @extended_modules ||= begin
      parents = @type.metaclass.parents || [] of Crystal::Type
      extended_modules = [] of Type
      parents.each do |parent|
        if parent.module? || parent.is_a?(IncludedGenericModule)
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
          when GenericClassInstanceType, CStructOrUnionType
            next
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

  def container
    case type = @type
    when NamedType
      container = type.container
      if container.is_a?(Program)
        nil
      else
        @generator.type(container)
      end
    when IncludedGenericModule
      @generator.type(type.module).container
    when InheritedGenericClass
      @generator.type(type.extended_class).container
    else
      nil
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
    if container = container()
      container.full_name_without_type_vars(io)
      io << "::"
    end
    io << name
  end

  def path
    if program?
      "toplevel.html"
    elsif container = container()
      "#{container.dir}/#{name}.html"
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
      container = type.container || @generator.program_type
      "#{path_to(container)}##{type.name}"
    else
      path_to(type.path)
    end
  end

  def link_from(type : Type)
    type.type_to_html self
  end

  def dir
    if container = container()
      "#{container.dir}/#{name}"
    else
      name.to_s
    end
  end

  def nesting
    if container = container()
      1 + container.nesting
    else
      0
    end
  end

  def doc
    @type.doc
  end

  def lookup_type(path_or_names)
    match = @type.lookup_type(path_or_names)
    return unless match.is_a?(Crystal::Type)

    @generator.type(match)
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
      type_vars.join(", ", io)
      io << '*' if type.is_a?(GenericType) && type.variadic
      io << ')'
    end
  end

  def node_to_html(node)
    String.build { |io| node_to_html node, io }
  end

  def node_to_html(node : Path, io, links = true)
    # We don't want "::" prefixed in from of paths in the docs
    old_global = node.global
    node.global = false

    begin
      match = lookup_type(node)
      if match
        type_to_html match, io, node.to_s, links: links
      else
        io << node
      end
    ensure
      node.global = old_global
    end
  end

  def node_to_html(node : Generic, io, links = true)
    match = lookup_type(node.name)
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

  def node_to_html(node : Fun, io, links = true)
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
    node.types.join(" | ", io) do |elem|
      node_to_html elem, io, links: links
    end
  end

  def node_to_html(node, io, links = true)
    io << node
  end

  def type_to_html(type)
    String.build { |io| type_to_html(type, io) }
  end

  def type_to_html(type : Crystal::UnionType, io, text = nil, links = true)
    type.union_types.join(" | ", io) do |union_type|
      type_to_html union_type, io, text, links: links
    end
  end

  def type_to_html(type : Crystal::FunInstanceType, io, text = nil, links = true)
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

  def type_to_html(type : Crystal::GenericClassInstanceType, io, text = nil, links = true)
    generic_class = @generator.type(type.generic_class)
    if generic_class.must_be_included?
      if links
        io << %(<a href=")
        io << generic_class.path_from(self)
        io << %(">)
      end
      if text
        io << text
      else
        generic_class.full_name_without_type_vars(io)
      end
      if links
        io << "</a>"
      end
    else
      if text
        io << text
      else
        generic_class.full_name_without_type_vars(io)
      end
    end
    io << '('
    type.type_vars.values.join(", ", io) do |type_var|
      case type_var
      when Var
        type_to_html type_var.type, io, links: links
      when Crystal::Type
        type_to_html type_var, io, links: links
      end
    end
    io << ')'
  end

  def type_to_html(type : Crystal::VirtualType, io, text = nil, links = true)
    type_to_html type.base_type, io, text, links: links
  end

  def type_to_html(type : Crystal::Type, io, text = nil, links = true)
    type_to_html @generator.type(type), io, text, links: links
  end

  def type_to_html(type : Type, io, text = nil, links = true)
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
      elsif container = container()
        "#{container.dir}/#{name}"
      else
        "#{name}"
      end
    )
  end
end
