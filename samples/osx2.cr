#!/usr/bin/env bin/crystal --run
require "objc"

NSAutoreleasePool.new
app = NSApplication.sharedApplication

# app.activationPolicy = NSApplication::ActivationPolicyRegular

# menubar = NSMenu.new.autorelease
# appMenuItem = NSMenuItem.new.autorelease
# menubar << appMenuItem
# app.mainMenu = menubar

window = NSWindow.new(NSRect.new(30, 0, 200, 200), 1_u64, 2_u64, 0_u8)
window.makeKeyAndOrderFront = nil

# app.activateIgnoringOtherApps = true

app.run

# C.getchar
