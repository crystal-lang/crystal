x = ->{}
x.call
# CHECK:      extractvalue %"->" %{{[0-9]+}}, 0
# CHECK-SAME: !dbg [[LOC:![0-9]+]]
# CHECK:      ctx_is_null:
# CHECK:      call %Nil
# CHECK-SAME: !dbg [[LOC]]
# CHECK:      ctx_is_not_null:
# CHECK:      call %Nil
# CHECK-SAME: !dbg [[LOC]]
# CHECK:      [[LOC]] = !DILocation
# CHECK-SAME: line: 2
# CHECK-SAME: column: 3
