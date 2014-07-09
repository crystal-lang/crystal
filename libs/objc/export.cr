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

    def initialize(pointer : UInt8*)
      super
    end

    {{yield}}
  end
end

macro objc_export(method_name)
  $x_{{@class_name.id}}_{{method_name.id}}_imp = ->(obj : UInt8*, _cmd : LibObjC::SEL) {
    {{@class_name.id}}.new(obj).{{method_name.id}}
  }
  LibObjC.class_addMethod($x_{{@class_name.id}}_objc_class.obj, {{method_name.id.stringify}}.to_sel, $x_{{@class_name.id}}_{{method_name.id}}_imp, "v@:")
end
