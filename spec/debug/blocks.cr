["hello world"].each do |v|
  a = v
  # print: a
  # lldb-check: (String *) {{(\$[0-9]+ = )?}}{{0x[0-9a-f]+}} "hello world"
  # gdb-check: $1 = "hello world"
  # print: v
  # lldb-check: (String *) {{(\$[0-9]+ = )?}}{{0x[0-9a-f]+}} "hello world"
  # gdb-check: $2 = "hello world"
  debugger
end
