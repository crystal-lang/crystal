a = "hello world"
b = "abcσdeσf"
# print: a
# lldb-check: (String *) $0 = {{0x[0-9a-f]+}} "hello world"
# gdb-check: $1 = "hello world"
# print: b
# lldb-check: (String *) $1 = {{0x[0-9a-f]+}} "abcσdeσf"
# gdb-check: $2 = "abcσdeσf"
debugger
