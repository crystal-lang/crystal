module Crystal
  class Program
    # Which kind of warnings wants to be detected.
    property warnings : Warnings = Warnings::All

    # Paths to ignore for warnings detection.
    property warnings_exclude : Array(String) = [] of String

    # Detected warning failures.
    property warning_failures = [] of String

    # If `true` compiler will error if warnings are found.
    property error_on_warnings : Bool = false

    @deprecated_methods_detected = Set(String).new
    @deprecated_macros_detected = Set(String).new
    @deprecated_aliases_detected = Set(String).new
    @deprecated_annotations_detected = Set(String).new

    def report_warning(node : ASTNode, message : String)
      return unless self.warnings.all?
      return if self.ignore_warning_due_to_location?(node.location)

      self.warning_failures << node.warning(message)
    end

    def report_warning_at(location : Location?, message : String)
      return unless self.warnings.all?
      return if self.ignore_warning_due_to_location?(location)

      if location
        message = String.build do |io|
          exception = SyntaxException.new message, location.line_number, location.column_number, location.filename
          exception.warning = true
          exception.append_to_s(io, nil)
        end
      end

      self.warning_failures << message
    end

    def ignore_warning_due_to_location?(location : Location?)
      return false unless location

      filename = location.original_filename
      return false unless filename

      @program.warnings_exclude.any? do |path|
        filename.starts_with?(path)
      end
    end

    def check_call_to_deprecated_alias(node : Alias) : Nil
      return unless @warnings.all?

      if (ann = node.annotation(deprecated_annotation)) && (deprecated_annotation = DeprecatedAnnotation.from(ann))
        self.validate_call_to_deprecated_node node, node.location, node.short_reference, deprecated_annotation do |warning_key|
          @deprecated_aliases_detected.add? warning_key
        end
      end
    end

    def check_call_to_deprecated_annotation(node : AnnotationDef) : Nil
      return unless @warnings.all?

      if (ann = node.annotation(deprecated_annotation)) && (deprecated_annotation = DeprecatedAnnotation.from(ann))
        self.validate_call_to_deprecated_node node, node.location, node.short_reference, deprecated_annotation do |warning_key|
          @deprecated_annotations_detected.add? warning_key
        end
      end
    end

    def check_call_to_deprecated_macro(node : Macro, call : Call)
      return unless @warnings.all?

      if (ann = node.annotation(self.deprecated_annotation)) && (deprecated_annotation = DeprecatedAnnotation.from(ann))
        call_location = call.location.try(&.macro_location) || call.location

        self.validate_call_to_deprecated_node call, call_location, node.short_reference, deprecated_annotation do |warning_key|
          @deprecated_macros_detected.add? warning_key
        end
      end
    end

    def check_call_to_deprecated_method(node : Call)
      return unless @warnings.all?

      node.target_defs.try &.each do |target_def|
        if (ann = target_def.annotation(deprecated_annotation)) && (deprecated_annotation = DeprecatedAnnotation.from(ann))
          return if self.compiler_expanded_call(node)

          self.validate_call_to_deprecated_node node, node.location, target_def.short_reference, deprecated_annotation do |warning_key|
            @deprecated_methods_detected.add? warning_key
          end
        end
      end
    end

    private def validate_call_to_deprecated_node(node : ASTNode, location : Location?, short_reference : String, deprecated_annotation : DeprecatedAnnotation, & : String -> Bool) : Nil
      return if self.ignore_warning_due_to_location? location
      warning_key = location.try { |l| "#{short_reference} #{l}" }

      # skip warning if the call site was already informed
      # if there is no location information just inform it.
      return if !warning_key || !yield(warning_key)

      message = deprecated_annotation.message
      message = message ? " #{message}" : ""

      self.warning_failures << node.warning "Deprecated #{short_reference}.#{message}"
    end

    private def compiler_expanded_call(node : Call)
      # Compiler generates a `_.initialize` call in `new`
      node.obj.as?(Var).try { |v| v.name == "_" } && node.name == "initialize"
    end
  end

  class Alias
    def short_reference
      "alias #{resolved_type}"
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

  class Command
    def report_warnings
      compiler = @compiler
      return unless compiler

      program = compiler.program?
      return unless program
      return if program.warning_failures.empty?

      program.warning_failures.each do |message|
        STDERR.puts message
        STDERR.puts "\n"
      end
      STDERR.puts "A total of #{program.warning_failures.size} warnings were found."
    end

    def warnings_fail_on_exit?
      compiler = @compiler
      return false unless compiler

      program = compiler.program
      program.error_on_warnings && program.warning_failures.size > 0
    end
  end
end
