require "../warnings"

module Crystal
  class Program
    # Warning settings and all detected warnings.
    property warnings = WarningCollection.new

    @deprecated_constants_detected = Set(String).new
    @deprecated_methods_detected = Set(String).new
    @deprecated_macros_detected = Set(String).new
    @deprecated_annotations_detected = Set(String).new

    def check_deprecated_constant(const : Const, node : Path)
      return unless @warnings.level.all?

      check_deprecation(const, node, @deprecated_constants_detected)
    end

    def check_call_to_deprecated_macro(a_macro : Macro, call : Call)
      return unless @warnings.level.all?

      check_deprecation(a_macro, call, @deprecated_macros_detected)
    end

    def check_call_to_deprecated_method(node : Call)
      return unless @warnings.level.all?
      return if compiler_expanded_call(node)

      node.target_defs.try &.each do |target_def|
        check_deprecation(target_def, node, @deprecated_methods_detected)
      end
    end

    def check_call_to_deprecated_annotation(node : AnnotationDef) : Nil
      return unless @warnings.level.all?

      check_deprecation(node, node.name, @deprecated_annotations_detected)
    end

    private def check_deprecation(object, use_site, detects)
      if (ann = object.annotation(self.deprecated_annotation)) &&
         (deprecated_annotation = DeprecatedAnnotation.from(ann))
        use_location = use_site.location.try(&.macro_location) || use_site.location
        return if !use_location || @warnings.ignore_warning_due_to_location?(use_location)

        # skip warning if the use site was already informed
        name = object.short_reference
        warning_key = "#{name} #{use_location}"
        return if detects.includes?(warning_key)
        detects.add(warning_key)

        full_message = String.build do |io|
          io << "Deprecated " << name << '.'
          if message = deprecated_annotation.message
            io << ' ' << message
          end
        end

        @warnings.infos << use_site.warning(full_message)
      end
    end

    private def compiler_expanded_call(node : Call)
      # Compiler generates a `_.initialize` call in `new`
      node.obj.as?(Var).try { |v| v.name == "_" } && node.name == "initialize"
    end
  end

  class AnnotationDef
    def short_reference
      "annotation #{resolved_type}"
    end
  end

  class Macro
    def short_reference
      case owner
      when Program
        "top-level #{name}"
      when MetaclassType
        "#{owner.instance_type.to_s(generic_args: false)}.#{name}"
      else
        "#{owner}.#{name}"
      end
    end
  end

  struct DeprecatedAnnotation
    getter message : String?

    def initialize(@message = nil)
    end

    def self.from(ann : Annotation)
      args = ann.args
      named_args = ann.named_args

      if named_args
        ann.raise "too many named arguments (given #{named_args.size}, expected maximum 0)"
      end

      message = nil
      count = 0

      args.each do |arg|
        case count
        when 0
          arg.raise "first argument must be a String" unless arg.is_a?(StringLiteral)
          message = arg.value
        else
          ann.wrong_number_of "deprecated annotation arguments", args.size, "1"
        end

        count += 1
      end

      new(message)
    end
  end

  class Def
    def short_reference
      case owner
      when Program
        "top-level #{name}"
      when .metaclass?
        "#{owner.instance_type}.#{name}"
      else
        "#{owner}##{name}"
      end
    end
  end

  class Const
    def short_reference
      to_s
    end
  end
end
