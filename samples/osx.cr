#!/usr/bin/env bin/crystal --run

# based on http://www.cocoawithlove.com/2010/09/minimalist-cocoa-programming.html
require "objc"

NSAutoreleasePool.new
NSApplication.sharedApplication

NSApp.activationPolicy = NSApplication::ActivationPolicyRegular

menubar = NSMenu.new
appMenuItem = NSMenuItem.new
menubar << appMenuItem
NSApp.mainMenu = menubar

appMenu = NSMenu.new
appName = NSProcessInfo.processInfo.processName

quitMenuItem = NSMenuItem.new "Quit #{appName}", "terminate:", "q"
appMenu << quitMenuItem
appMenuItem.submenu = appMenu

window = NSWindow.new(NSRect.new(0, 0, 200, 200), NSWindow::NSTitledWindowMask, NSWindow::NSBackingStoreBuffered, false)
window.cascadeTopLeftFromPoint = NSPoint.new(20, 20)
window.title = appName
window.makeKeyAndOrderFront = nil


fooClass = ObjCClass.new(LibObjC.allocateClassPair(ObjCClass.new("NSObject").obj, "Foo", 0_u32))
imp = ->(_self : UInt8*, _cmd : LibObjC::SEL) {
  puts "Hi there"
}
LibObjC.class_addMethod(fooClass.obj, "bar".to_sel, imp, "v@:")
foo0 = LibObjC.msgSend(fooClass, "alloc".to_sel)
foo = LibObjC.msgSend(foo0, "init".to_sel)
LibObjC.msgSend(foo, "bar".to_sel)

b = NSButton.new NSRect.new(50, 50, 100, 100)
# b.action = "terminate:"
b.target = foo
b.action = "bar"
window.contentView.addSubview b

NSApp.activateIgnoringOtherApps = true
NSApp.run
