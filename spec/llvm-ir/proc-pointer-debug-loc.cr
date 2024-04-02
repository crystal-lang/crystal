def foo
end

(->foo).call

# CHECK:      define internal void @"~procProc(Nil)
# CHECK-SAME: !dbg [[LOC1:![0-9]+]]
# CHECK-NEXT: entry:
# CHECK-NEXT:   ret void, !dbg [[LOC2:![0-9]+]]
# CHECK-NEXT: }
# CHECK:      [[LOC2]] = !DILocation(line: 4, column: 2, scope: [[LOC1]])
