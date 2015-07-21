class A
  def foo
    1
  end
end

class B
  def foo
    2
  end
end

def bar(o)
  o.foo
end

def baz(o)
  o.foo
end

puts bar(A.new)
puts bar(B.new)
puts baz(A.new)


# ./crystal impl:samples/impl.cr:14:5 samples/impl.cr
#
# .../samples/impl.cr:2:3
# .../samples/impl.cr:8:3

# ./crystal impl:samples/impl.cr:18:5 samples/impl.cr
#
# .../samples/impl.cr:2:3

# ./crystal impl:samples/impl.cr:21:7 samples/impl.cr
#
# .../samples/impl.cr:13:1

# ./crystal impl:samples/impl.cr:22:3 samples/impl.cr
#
# .../src/kernel.cr:67:1
