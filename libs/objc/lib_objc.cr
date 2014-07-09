lib LibObjC("objc")
  # type Id : UInt8* #UInt64
  type SEL : Void*
  # type Class : UInt8*
  # type size_t : UInt32
  type IMP : Pointer(UInt8), LibObjC::SEL ->
  # type IMP : Void*

  fun getClass = objc_getClass(UInt8*) : UInt8*
  fun class_getName(UInt8*) : UInt8*
  fun msgSend = objc_msgSend(UInt8*, SEL, ...) : UInt8*

  fun sel_registerName(UInt8*) : SEL

  fun allocateClassPair = objc_allocateClassPair(UInt8*, UInt8*, UInt32) : UInt8*

  fun class_addMethod(UInt8*, SEL, IMP, UInt8*) : UInt8


end

lib LibCF("`echo \"-framework CoreFoundation\"`")
  type CFString : Void*

  fun str = __CFStringMakeConstantString(UInt8*) : CFString

  struct Point
    x : Float64
    y : Float64
  end

  struct Size
    width : Float64
    height : Float64
  end

  struct Rect
    origin : Point
    size : Size
  end
end

lib LibAppKit("`echo \"-framework AppKit\"`")
  fun ns_run_alert_panel = NSRunAlertPanel(LibCF::CFString, LibCF::CFString,
                               LibCF::CFString, LibCF::CFString, LibCF::CFString, ...);

  fun ns_application_main = NSApplicationMain(UInt32, UInt8**) : UInt32
end
