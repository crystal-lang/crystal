macro objc_class(class_name)
  class {{class_name}} < NSObject
    property :obj
  end

  $x_{{class_name}}_obj_map = {} of UInt8* => {{class_name}}

  $x_{{class_name}}_objc_class = ObjCClass.new(LibObjC.allocateClassPair(ObjCClass.new("NSObject").obj, "{{class_name}}", 0_u32))

  class {{class_name}}
    def self.mapped_class
      $x_{{class_name}}_objc_class.obj
    end

    def initialize
      @obj = initialize_using "init"
      $x_{{class_name}}_obj_map[@obj] = self
    end

    {{yield}}
  end
end

macro objc_export(class_name, method_name)
  $x_{{class_name}}_{{method_name}}_imp = ->(_self : UInt8*, _cmd : LibObjC::SEL) {
    o = $x_{{class_name}}_obj_map[_self] as {{class_name}}
    o.{{method_name}}
  }
  LibObjC.class_addMethod($x_{{class_name}}_objc_class.obj, "{{method_name}}".to_sel, $x_{{class_name}}_{{method_name}}_imp, "v@:")
end
