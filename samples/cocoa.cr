#!/usr/bin/env bin/crystal --run
require "objc"

pool = LibObjC.getClass("NSAutoreleasePool")

puts pool.address

pool = LibObjC.msgSend(pool, LibObjC.sel_registerName("alloc"))

puts pool.address

pool = LibObjC.msgSend(pool, LibObjC.sel_registerName("init"))

puts pool.address

app = LibObjC.msgSend(LibObjC.getClass("NSApplication"),
                       LibObjC.sel_registerName("sharedApplication"))

# LibAppKit.ns_application_main(0_u32, nil)

puts "sdf"

puts LibCF.str("Testing")

LibAppKit.ns_run_alert_panel(LibCF.str("Testing"),
                LibCF.str("This is a simple test to display NSAlertPanel."),
                LibCF.str("OK"), nil, nil)


puts "sdf"

LibObjC.msgSend(pool, LibObjC.sel_registerName("release"))
