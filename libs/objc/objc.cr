require "./*"

struct ObjCClass
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

  def to_nsbool
    (self != 0).to_nsbool
  end
end

struct Bool
  def to_nsbool
    self ? 0xFF_u8 : 0x00_u8
  end
end

struct NSObject
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
    if klass.name == "__NSCFString"
      NSString.new(o)
    else
      o
    end
  end

  def inbox(o)
    self.class.inbox(o)
  end

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

end

macro initializable_object(klass)
  struct {{klass}} < NSObject
    def initialize
      @obj = initialize_using "init"
    end

    {{yield}}
  end
end

struct NSString < NSObject
  def initialize(s : String)
    @obj = initialize_using "initWithUTF8String:", s.to_s.cstr
  end

  def length
    msgSend("length").address
  end

  def [](index : Int)
    msgSend("characterAtIndex:", index.to_nsuinteger).address.chr
  end

  def to_s
    String.new(msgSend("UTF8String"))
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

struct NSApplication < NSObject
  ActivationPolicyRegular = 0.to_nsinteger

  def self.sharedApplication
    NSApplication.new(msgSend("sharedApplication"))
  end

  def run
    msgSend "run"
  end

  def activationPolicy=(policy)
    msgSend "setActivationPolicy:", policy.to_nsinteger
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
    @obj = LibObjC.msgSend(obj, "initWithTitle:action:keyEquivalent:".to_sel, title.to_nsstring, action.to_sel, keyEquivalent.to_nsstring)
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
end

struct NSRect
  property :obj

  def initialize(x, y, w, h)
    @obj = LibCF::Rect.new
    @obj.origin = NSPoint.new(x, y).obj
    @obj.size.width = w.to_cgfloat
    @obj.size.height = h.to_cgfloat
    puts "rect built"
    @obj
  end
end

struct NSWindow < NSObject
  NSTitledWindowMask = 1_u64.to_nsuinteger

  NSBackingStoreBuffered = 2_u64.to_nsuinteger

  def initialize(rect, styleMask, backing, defer)
    obj = self.class.msgSend "alloc"
    @obj = LibObjC.msgSend(obj, "initWithContentRect:styleMask:backing:defer:".to_sel, rect, styleMask, backing, defer)
  end

  def cascadeTopLeftFromPoint=(point : NSPoint)
    msgSend "cascadeTopLeftFromPoint:", point
  end

  def title=(value)
    msgSend "setTitle:", value.to_nsstring
  end

  def makeKeyAndOrderFront=(value)
    msgSend "makeKeyAndOrderFront:", value
  end
end

struct NSProcessInfo < NSObject
  def self.processInfo
    NSProcessInfo.new(msgSend("processInfo"))
  end

  def processName
    NSString.new(msgSend("processName"))
  end
end
