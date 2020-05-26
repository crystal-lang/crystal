module Crystal
  class Program
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

    @deprecated_macros_detected = Set(String).new

    def check_call_to_deprecated_macro(a_macro : Macro, call : Call)
      return unless self.warnings.all?

      if (ann = a_macro.annotation(self.deprecated_annotation)) &&
         (deprecated_annotation = DeprecatedAnnotation.from(ann))
        call_location = call.location.try(&.macro_location) || call.location

        return if self.ignore_warning_due_to_location?(call_location)
        short_reference = a_macro.short_reference
        warning_key = call_location.try { |l| "#{short_reference} #{l}" }

        # skip warning if the call site was already informed
        # if there is no location information just inform it.
        return if !warning_key || @deprecated_macros_detected.includes?(warning_key)
        @deprecated_macros_detected.add(warning_key) if warning_key

        message = deprecated_annotation.message
        message = message ? " #{message}" : ""

        full_message = call.warning "Deprecated #{short_reference}.#{message}"

        self.warning_failures << full_message
      end
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
end
