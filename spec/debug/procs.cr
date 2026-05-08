x = ->(n : Int32) { n + 1 }
y : Proc(Int32, Int32)? = ->(n : Int32) { n + 2 }
captured = 40
z = ->(n : Int32) { captured + n }

# print: x
# lldb-check: (Proc(Int32, Int32)) {
# lldb-check: func = {{0x[0-9a-f]+}} {{.*}}procs.cr:1{{.*}}
# lldb-check: closure_data = 0x0000000000000000
# lldb-check: }
# gdb-check: {func = {{0x[0-9a-f]+}} <->>, closure_data = 0x0}
#
# print: y
# lldb-check: (Proc(Int32, Int32)) {
# lldb-check: func = {{0x[0-9a-f]+}} {{.*}}procs.cr:2{{.*}}
# lldb-check: closure_data = 0x0000000000000000
# lldb-check: }
# gdb-check: {func = {{0x[0-9a-f]+}} <->>, closure_data = 0x0}
#
# print: z
# lldb-check: (Proc(Int32, Int32)) {
# lldb-check: func = {{0x[0-9a-f]+}} {{.*}}procs.cr:4{{.*}}
# lldb-check: closure_data = {{0x0*[1-9a-f][0-9a-f]*}}
# lldb-check: }
# gdb-check: {func = {{0x[0-9a-f]+}} <->>, closure_data = {{0x[0-9a-f]+}}}
debugger
