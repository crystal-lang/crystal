lib Foo
  fun foo(x : ->)
end

def raise(msg)
  while true
  end
end

x = 1
f = ->{ x }
Foo.foo(f)

# CHECK:      define internal i8* @"~check_proc_is_not_closure"(%"->" %0)
# CHECK:      ctx_is_not_null:
# CHECK-NEXT: call void @"*raise<String>:NoReturn"
# CHECK-SAME: !dbg [[LOC1:![0-9]+]]
# CHECK:      [[LOC1]] = !DILocation
# CHECK-SAME: line: 0
