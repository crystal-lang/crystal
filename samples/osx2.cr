#!/usr/bin/env bin/crystal --run
require "objc"

NSApplication.sharedApplication
NSApp.activationPolicy = NSApplication::ActivationPolicyRegular

window = NSWindow.new(NSRect.new(50, 50, 200, 200), NSWindow::NSTitledWindowMask, NSWindow::NSBackingStoreBuffered, false)
window.makeKeyAndOrderFront = nil

NSApp.run
