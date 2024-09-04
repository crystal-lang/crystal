class Foo
  def self.foo
    @@x
    # CHECK:      call i32* @"~Foo+.class::x:read"
    # CHECK-SAME: !dbg [[LOC3:![0-9]+]]
    # CHECK:      [[LOC3]] = !DILocation
    # CHECK-SAME: line: [[# @LINE - 4]]
    # CHECK-SAME: column: 5
  end

  @@x = 1
end

class Bar < Foo
end

(Foo || Bar).foo
