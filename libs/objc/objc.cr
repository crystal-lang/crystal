require "./*"

struct ObjCClass
  property :obj

  def initialize(c : UInt8*)
    @obj = c
  end

  def initialize(className : String)
    @obj = LibObjC.getClass(className)
  end

  def name
    String.new(LibObjC.class_getName(@obj))
  end
end

class String
  def to_cf_str
    LibCF.str self
  end

  def to_nsstring
    NSString.new self
  end

  def to_sel
    LibObjC.sel_registerName(self)
  end
end

struct Nil
  def to_sel
    self
  end

  def obj
    nil
  end
end

struct Float
  def to_cgfloat
    self.to_f64
  end

  def to_nsinteger
    self.to_i64.to_nsinteger
  end
end

struct Int
  def to_cgfloat
    self.to_f64.to_cgfloat
  end

  def to_nsinteger
    self.to_i64
  end

  def to_nsuinteger
    self.to_u64
  end

  def to_nsenum
    self.to_u64
  end

  def to_nsbool
    (self != 0).to_nsbool
  end
end

struct Bool
  def to_nsbool
    self ? 0xFF_u8 : 0x00_u8
  end
end

# class Object
#   def initialize(pointer : UInt8*)
#     # required for compilation
#     raise "Should be a NSObject based class"
#   end
# end

# macro checked_wrap(expectedType, o)
#   o = {{o}}
#   klass = ObjCClass.new(LibObjC.msgSend(o, "class".to_sel))
#   raise "Expected #{{{expectedType}}} got #{klass.name}" if klass.name != {{expectedType}}.to_s
#   {{expectedType}}.new(o)
# end

macro checked_wrap(expectedType, o)
  {{expectedType}}.new({{o}})
end

class NSObject
  property :obj

  # region parameters outboxing
  def self.outbox(p)
    if p.is_a?(NSObject)
      p.obj
    else
      p
    end
  end

  def outbox(p)
    self.class.outbox(p)
  end

  def self.inbox(o)
    klass = ObjCClass.new(LibObjC.msgSend(o, "class".to_sel))
    # map = {
    #   "__NSCFString" => NSString.class,
    #   "NSView" => NSView.class
    # }
    # target = map.fetch(klass, nil)
    # if target.nil?
    #   puts "Obj-c inbox unmatched for class #{klass}"
    #   o
    # else
    #   target.new(o)
    # end

    if klass.name == "__NSCFString"
      NSString.new(o)
    elsif klass.name == "NSView"
      NSView.new(o)
    else
      o
    end
  end

  def inbox(o)
    self.class.inbox(o)
  end

  # def self.inbox(expectedType, o)
  #   klass = ObjCClass.new(LibObjC.msgSend(o, "class".to_sel))
  #   raise "Expected #{expectedType} got #{klass.name}" if klass.name != expectedType.to_s
  #   expectedType.new(o)
  # end

  # def inbox(expectedType, o)
  #   self.class.inbox(expectedType, o)
  # end

  # end

  def self.mapped_class
    LibObjC.getClass(to_s)
  end

  def initialize_using(init_method)
    #TODO replace obj for @obj
    obj = self.class.msgSend "alloc"
    LibObjC.msgSend(obj, init_method.to_sel)
  end

  def initialize_using(init_method, arg0)
    #TODO replace obj for @obj
    obj = self.class.msgSend "alloc"
    LibObjC.msgSend(obj, init_method.to_sel, outbox(arg0))
  end

  def initialize(pointer : UInt8*)
    @obj = pointer
    retain
  end

  def finalize
    release
  end

  def autorelease
    msgSend "autorelease"
    self
  end

  def retain
    msgSend "retain"
    self
  end

  def release
    msgSend "release"
    self
  end

  def performSelectorOnMainThread(sel, withObject, waitUntilDone)
    msgSend "performSelectorOnMainThread:withObject:waitUntilDone:", sel.to_sel, withObject.obj, waitUntilDone.to_nsbool
  end

  def objc_class
    ObjCClass.new(msgSend("class"))
  end

  def self.msgSend(name)
    LibObjC.msgSend(self.mapped_class, name.to_sel)
  end

  def self.msgSend(name, arg0)
    LibObjC.msgSend(self.mapped_class, name.to_sel, outbox(arg0))
  end

  def self.msgSend(name, arg0, arg1, arg2, arg3)
    LibObjC.msgSend(self.mapped_class, name.to_sel, outbox(arg0), outbox(arg1), outbox(arg2), outbox(arg3))
  end

  def msgSend(name)
    LibObjC.msgSend(self.obj, name.to_sel)
  end

  def msgSend(name, arg0)
    LibObjC.msgSend(self.obj, name.to_sel, outbox(arg0))
  end

  def msgSend(name, arg0, arg1)
    LibObjC.msgSend(self.obj, name.to_sel, outbox(arg0), outbox(arg1))
  end

  def msgSend(name, arg0, arg1, arg2)
    LibObjC.msgSend(self.obj, name.to_sel, outbox(arg0), outbox(arg1), outbox(arg2))
  end

end

macro initializable_object(klass)
  class {{klass.id}} < NSObject
    def initialize
      @obj = initialize_using "init"
    end

    {{yield}}
  end
end

class NSString < NSObject
  def initialize(s : String)
    @obj = initialize_using "initWithUTF8String:", s.to_s.cstr
  end

  def initialize(s : UInt8*)
    super(s)
  end

  def length
    msgSend("length").address
  end

  def [](index : Int)
    msgSend("characterAtIndex:", index.to_nsuinteger).address.chr
  end

  def to_s(io)
    io << String.new(msgSend("UTF8String"))
  end

  def to_nsstring
    self
  end
end

initializable_object :NSMutableArray do
  def count
    msgSend("count").address
  end

  def << (item)
    msgSend "addObject:", item
    self
  end

  def [](index)
    inbox(msgSend("objectAtIndex:", index.to_nsuinteger))
  end
end


initializable_object :NSAutoreleasePool

NSApp = NSApplication.sharedApplication

class NSApplication < NSObject
  ActivationPolicyRegular = 0
  ActivationPolicyAccessory = 1
  ActivationPolicyProhibited = 2

  def self.sharedApplication
    NSApplication.new(msgSend("sharedApplication"))
  end

  def run
    msgSend "run"
  end

  def activationPolicy=(policy)
    msgSend "setActivationPolicy:", policy.to_nsenum
  end

  def activateIgnoringOtherApps=(value)
    msgSend "activateIgnoringOtherApps:", value.to_nsbool
  end

  def mainMenu=(menu : NSMenu)
    msgSend "setMainMenu:", menu
  end
end

initializable_object :NSMenu do
  def <<(item : NSMenuItem)
    msgSend "addItem:", item
  end
end

initializable_object :NSMenuItem do
  def initialize(title : String, action : String?, keyEquivalent : String)
    obj = self.class.msgSend "alloc"
    @obj = LibObjC.msgSend(obj, "initWithTitle:action:keyEquivalent:".to_sel, outbox(title.to_nsstring), outbox(action.to_sel), outbox(keyEquivalent.to_nsstring))
  end

  def title=(value)
    msgSend "setTitle:", value
  end

  def submenu=(menu : NSMenu)
    msgSend "setSubmenu:", menu
  end
end

struct NSPoint
  property :obj

  def initialize(x, y)
    @obj = LibCF::Point.new
    @obj.x = x.to_cgfloat
    @obj.y = y.to_cgfloat
    @obj
  end

  delegate x, @obj
  delegate y, @obj
end

struct NSSize
  property :obj

  def initialize(width, height)
    @obj = LibCF::Size.new
    @obj.width = width.to_cgfloat
    @obj.height = height.to_cgfloat
    @obj
  end

  delegate width, @obj
  delegate height, @obj
end

struct NSRect
  property :obj

  def initialize(x, y, w, h)
    @obj = LibCF::Rect.new
    @obj.origin = NSPoint.new(x, y).obj
    @obj.size = NSSize.new(w, h).obj
    @obj
  end

  delegate origin, @obj
  delegate size, @obj
end

class NSWindow < NSObject
  NSTitledWindowMask = 1
  NSBackingStoreBuffered = 2

  def initialize(rect : NSRect, styleMask, backing, defer)
    obj = self.class.msgSend "alloc"
    @obj = LibObjC.msgSend(obj, "initWithContentRect:styleMask:backing:defer:".to_sel, outbox(rect), outbox(styleMask.to_nsuinteger), outbox(backing.to_nsenum), outbox(defer.to_nsbool))
  end

  def cascadeTopLeftFromPoint=(point : NSPoint)
    msgSend "cascadeTopLeftFromPoint:", point
  end

  def title=(value)
    msgSend "setTitle:", value.to_nsstring
  end

  def addSubview(view)
    msgSend "addSubview:", view
  end

  def makeKeyAndOrderFront=(value)
    msgSend "makeKeyAndOrderFront:", value
  end

  def contentView
    checked_wrap(NSView, msgSend("contentView"))
  end
end

class NSView < NSObject
  def initialize(rect : NSRect)
    obj = self.class.msgSend "alloc"
    @obj = LibObjC.msgSend(obj, "initWithFrame:".to_sel, outbox(rect))
  end

  def initialize(pointer : UInt8*)
    super
  end

  def addSubview(view)
    msgSend "addSubview:", view
  end
end

class NSControl < NSObject
  def initialize(rect : NSRect)
    obj = self.class.msgSend "alloc"
    @obj = LibObjC.msgSend(obj, "initWithFrame:".to_sel, outbox(rect))
  end

  def value=(value : String)
    msgSend "setStringValue:", value.to_nsstring
  end

  def string_value
    checked_wrap(NSString, msgSend("stringValue")).to_s
  end

  def action=(value)
    msgSend "setAction:", value.to_sel
  end

  def target=(value)
    msgSend "setTarget:", value
  end
end

class NSButton < NSControl
  def title=(value)
    msgSend "setTitle:", value.to_nsstring
  end
end

class NSTextField < NSControl
  def value
    self.string_value
  end
end

class NSProcessInfo < NSObject
  def self.processInfo
    NSProcessInfo.new(msgSend("processInfo"))
  end

  def processName
    checked_wrap(NSString, msgSend("processName")).to_s
  end
end
