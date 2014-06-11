#!/usr/bin/env bin/crystal --run
require "objc"

puts NSProcessInfo.processInfo.processName

pool = NSAutoreleasePool.new

app = NSApplication.sharedApplication

# # LibAppKit.ns_application_main(0_u32, nil)

# puts "sdf"

NSRect.new 0,0,0,0

puts sizeof(NSRect)
puts sizeof(LibCF::Rect)


puts sizeof(NSPoint)
puts sizeof(LibCF::Point)

LibAppKit.ns_run_alert_panel("Testing".to_nsstring.obj as LibCF::CFString,
                "This is a simple test to display NSAlertPanel.".to_nsstring.obj as LibCF::CFString,
                "OK".to_nsstring.obj as LibCF::CFString, nil, nil)

# puts "sdf"

pool.release
