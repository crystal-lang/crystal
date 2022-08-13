a = "hello world"
# lldb-command: print a
# lldb-check: (String *) $0 = {{0x[0-9a-f]+}} "hello world"
debugger
