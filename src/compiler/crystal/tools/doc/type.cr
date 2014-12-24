require "ecr/macros"

class Crystal::Doc::Type
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
      type.mapping.values
    when IncludedGenericModule
      type.mapping.values
    else
      nil
    end
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

  def types
    @types ||= @generator.collect_subtypes(@type)
  end

  def instance_methods
    @instance_methods ||= begin
      case type = @type
      when DefContainer
        defs = [] of Method
        type.defs.try &.each do |def_name, defs_with_metadata|
          defs_with_metadata.each do |def_with_metadata|
            case def_with_metadata.def.visibility
            when :private, :protected
              next
            end

            if @generator.must_include? def_with_metadata.def
              defs << @generator.method(def_with_metadata.def)
            end
          end
        end
        defs.sort_by! &.name
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
          type.defs.try &.each do |def_name, defs_with_metadata|
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
                defs << @generator.method(a_def)
              end
            end
          end
          defs.sort_by! &.name
        else
          [] of Method
        end

      # Also get `initialize` methods from instance type,
      # but show them as `new`
      case type = @type
      when DefContainer
        type.defs.try &.each do |def_name, defs_with_metadata|
          defs_with_metadata.each do |def_with_metadata|
            a_def = def_with_metadata.def
            if a_def.name == "initialize" && @generator.must_include?(a_def)
              initialize = a_def.clone
              initialize.doc = a_def.doc
              initialize.name = "new"
              class_methods << @generator.method(initialize)
            end
          end
        end
      end

      class_methods
    end
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
      included_modules.sort_by! &.name
    end
  end

  def subclasses
    @subclasses ||= begin
      case type = @type
      when ClassType
        subclasses = [] of Type
        type.subclasses.each do |subclass|
          case subclass
          when GenericClassInstanceType
            next
          end

          subclasses << @generator.type(subclass)
        end
        subclasses.sort_by! &.name
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
    if container = container()
      io << container.full_name(io)
      io << "::"
      io << name
    else
      io << name
    end
    append_type_vars io
  end

  def doc
    @type.doc
  end

  def to_s(io)
    io << name
    append_type_vars io
  end

  def render(__io__)
    embed_ecr "#{__DIR__}/type.ecr", "__io__"
  end

  private def append_type_vars(io)
    if type_vars = type_vars()
      io << '('
      type_vars.each_with_index do |type_var, i|
        io << ", " if i > 0
        io << type_var
      end
      io << ')'
    end
  end
end
