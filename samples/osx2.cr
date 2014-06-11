#!/usr/bin/env bin/crystal --run
require "objc"

NSAutoreleasePool.new
app = NSApplication.sharedApplication

app.activationPolicy = NSApplication::ActivationPolicyRegular

# menubar = NSMenu.new
# appMenuItem = NSMenuItem.new
# menubar << appMenuItem

# app.mainMenu = menubar

window = NSWindow.new(NSRect.new(30, 0, 200, 200), NSWindow::NSTitledWindowMask, NSWindow::NSBackingStoreBuffered, false)
window.makeKeyAndOrderFront = nil

app.activateIgnoringOtherApps = true

app.run

# app.performSelectorOnMainThread "run", nil, true

# C.getchar
