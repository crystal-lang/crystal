class Foo
  property lorem : Int32?

  def foo
    1
  end
end

class Bar
  def foo
    2
  end
end

def bar(o)
  while false
    o.foo
  end
end

def baz(o)
  o.foo
end

puts bar(Foo.new)
puts bar(Bar.new)
puts baz(Foo.new)

Foo.new.lorem

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:17:8
#
# 2 implementations found
# .../samples/impl.cr:4:3
# .../samples/impl.cr:10:3

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:22:5
#
# 1 implementation found
# .../samples/impl.cr:4:3

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:25:7
#
# 1 implementation found
# .../samples/impl.cr:15:1

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:27:3
#
# 1 implementation found
# .../share/crystal/src/kernel.cr:369:1

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:29:9
#
# 1 implementation found
# .../samples/impl.cr:2:3
#  ~> macro property: expanded macro: macro_139913700784656:636:13
