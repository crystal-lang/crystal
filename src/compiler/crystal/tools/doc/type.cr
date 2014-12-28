require "./item"

class Crystal::Doc::Type
  include Item

  getter type

  def initialize(@generator, @type : Crystal::Type)
  end

  def kind
    case @type
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
    when InheritedGenericClass
      type.extended_class.name
    when IncludedGenericModule
      type.module.name
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
    @type.abstract
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
      if superclass
        @generator.type(superclass)
      else
        nil
      end
    else
      nil
    end
  end

  def program?
    @type.is_a?(Program)
  end

  def enum?
    kind == :enum
  end

  def alias?
    kind == :alias
  end

  def alias_definition
    alias_def = (@type as AliasType).aliased_type
    alias_def
  end

  def formatted_alias_definition
    type_to_html alias_definition
  end

  def types
    @types ||= @generator.collect_subtypes(@type)
  end

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
            when :private, :protected
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
              when :private, :protected
                next
              end

              body = a_def.body

              # Skip auto-generated allocate method
              if body.is_a?(Primitive) && body.name == :allocate
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

  def constants
    @constants ||= @generator.collect_constants(self)
  end

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
          end

          subclasses << @generator.type(subclass)
        end
        subclasses.sort_by! &.full_name.downcase
      else
        [] of Type
      end
    end
  end

  def container
    case type = @type
    when ContainedType
      container = type.container
      if container.is_a?(Program)
        nil
      else
        @generator.type(container)
      end
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
    type.path_to(self)
  end

  def path_to(filename : String)
    "#{"../" * nesting}#{filename}"
  end

  def path_to(type : Type)
    path_to type.path
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
    instance_methods.find { |method| method.name == name }
  end

  def lookup_method(name, args_count)
    if args_count
      instance_methods.find { |method| method.name == name && method.args.length == args_count }
    else
      methods = instance_methods.select { |method| method.name == name }
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
    if type_vars = type_vars()
      io << '('
      type_vars.join(", ", io)
      io << ')'
    end
  end

  def node_to_html(node)
    String.build { |io| node_to_html node, io }
  end

  def node_to_html(node : Path, io)
    match = lookup_type(node)
    if match
      type_to_html match, io
    else
      io << node
    end
  end

  def node_to_html(node : Generic, io)
    node_to_html node.name, io
    io << "("
    node.type_vars.join(", ", io) do |type_var|
      node_to_html type_var, io
    end
    io << ")"
  end

  def node_to_html(node : Fun, io)
    if inputs = node.inputs
      inputs.join(", ", io) do |input|
        node_to_html input, io
      end
    end
    io << " -> "
    if output = node.output
      node_to_html output, io
    end
  end

  def node_to_html(node : Union, io)
    node.types.join(" | ", io) do |elem|
      node_to_html elem, io
    end
  end

  def node_to_html(node, io)
    io << node
  end

  def type_to_html(type)
    String.build { |io| type_to_html(type, io) }
  end

  def type_to_html(type : Crystal::UnionType, io)
    type.union_types.join(" | ", io) do |union_type|
      type_to_html union_type, io
    end
  end

  def type_to_html(type : Crystal::GenericClassInstanceType, io)
    generic_class = @generator.type(type.generic_class)
    io << %(<a href=")
    io << generic_class.path_from(self)
    io << %(">)
    io << generic_class.full_name_without_type_vars
    io << "</a>"
    io << '('
    type.type_vars.values.join(", ", io) do |type_var|
      case type_var
      when Var
        type_to_html type_var.type, io
      when Crystal::Type
        type_to_html type_var, io
      end
    end
    io << ')'
  end

  def type_to_html(type : Crystal::Type, io)
    type_to_html @generator.type(type), io
  end

  def type_to_html(type : Type, io)
    io << %(<a href=")
    io << type.path_from(self)
    io << %(">)
    io << type.full_name
    io << "</a>"
  end
end
