class Foo(T)
  # CHECK:      define internal %"Foo(Int32)"* @"*Foo(Int32)@Foo(T)::new:Foo(Int32)"(i32 %self)
  # CHECK-SAME: !dbg [[LOC1:![0-9]+]]
  # CHECK-NEXT: alloca:
  # CHECK-NEXT: %_ = alloca %"Foo(Int32)"*
  # CHECK-SAME: !dbg [[LOC2:![0-9]+]]
  # CHECK:      [[LOC2]] = !DILocation
  # CHECK-SAME: scope: [[LOC1]]
end

Foo(Int32).new
