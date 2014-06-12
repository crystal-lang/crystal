#!/usr/bin/env bin/crystal --run
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
puts "appName: #{appName}"

# quitMenuItem = NSMenuItem.new "Quit #{appName}", "terminate:", "q"
# appMenu << quitMenuItem
appMenuItem.submenu = appMenu

window = NSWindow.new(NSRect.new(0, 0, 200, 200), NSWindow::NSTitledWindowMask, NSWindow::NSBackingStoreBuffered, false)
window.cascadeTopLeftFromPoint = NSPoint.new(20, 20)
window.title = appName
window.makeKeyAndOrderFront = nil

NSApp.activateIgnoringOtherApps = true
NSApp.run
