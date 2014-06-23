macro objc_class(class_name)
  class {{class_name.id}} < NSObject
    property :obj
  end

  $x_{{class_name.id}}_objc_class = ObjCClass.new(LibObjC.allocateClassPair(ObjCClass.new("NSObject").obj, {{class_name.id.stringify}}, 0_u32))

  class {{class_name.id}}
    def self.mapped_class
      # the registered class is not been able to lookup by name
      $x_{{class_name.id}}_objc_class.obj
    end

    def initialize
      @obj = initialize_using "init"
    end

    {{yield}}
  end
end

macro objc_export(method_name)
  $x_{{@name.id}}_{{method_name.id}}_imp = ->(_self : UInt8*, _cmd : LibObjC::SEL) {
    {{@name.id}}.new(_self).{{method_name.id}}
  }
  LibObjC.class_addMethod($x_{{@name.id}}_objc_class.obj, {{method_name.id.stringify}}.to_sel, $x_{{@name.id}}_{{method_name.id}}_imp, "v@:")
end
