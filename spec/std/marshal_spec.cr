require "spec"
require "marshal"

def marshal(value, expected)
  expected_buffer = StringIO.new
  expected.each do |item|
    case item
    when Int then expected_buffer.write_byte(item.to_u8)
    when String then expected_buffer << item
    end
  end

  it "marshals #{value.inspect}" do
    buffer = StringIO.new
    value.save(buffer)
    buffer.to_slice.to_a.should eq(expected_buffer.to_slice.to_a)
    buffer.rewind
    typeof(value).load(buffer).should eq(value)
  end
end

enum MarshalEnum
  FOO
  BAR
  BAZ
end

class MarshalClass1
  def ==(other : MarshalClass1)
    true
  end
end

class MarshalClass2
  def initialize
    @x = 123
  end

  def ==(other : MarshalClass2)
    @x == other.@x
  end
end

class MarshalClass3
  def initialize
    @x = self
  end
  def ==(other : MarshalClass3)
    true
  end
end

class MarshalClass4
  def initialize
    @x = 1 || 1.1
    @y = 123
    @z = 2 || 2.2
  end
  def ==(other : MarshalClass4)
    @x == other.@x && @y == other.@y
  end
end

record MarshalRecord1, foo, bar

describe "Marshal" do
  marshal nil, [] of Int32
  marshal false, [0]
  marshal true, [1]
  marshal 123_i8, [123]
  marshal 123_u8, [123]
  marshal 123, [123]
  marshal 123456, [135, 196, 64]
  marshal 1.5, [0x3f, 0xf8, 0, 0, 0, 0, 0, 0]
  marshal 'á', [129, 97]
  marshal "foo", [0, 3, "foo"]
  marshal [1, 2, 3, 1000], [0, 4, 1, 2, 3, 135, 104]
  marshal [1, 2, true, false], [0, 4, 0, 5, "Int32", 1, 1, 2, 0, 4, "Bool", 1, 2, 0]
  marshal ({1 => 2, 3 => 4}), [0, 2, 1, 2, 3, 4]
  marshal ({1 => 2, 3 => 'a'}), [0, 2, 1, 0, 5, "Int32", 2, 3, 0, 4, "Char", 'a'.ord]
  marshal MarshalEnum::BAR, [1]
  marshal /foo/im, [(Regex::Options::MULTILINE | Regex::Options::IGNORE_CASE).value, 0, 3, "foo"]
  marshal MarshalClass1.new, [0]
  marshal MarshalClass2.new, [0, 123]
  marshal MarshalClass3.new, [0, 1]
  marshal MarshalClass4.new, [0, 0, 5, "Int32", 1, 123, 1, 2]
  marshal MarshalRecord1.new(123, 1 || 'a'), [123, 0, 5, "Int32", 1]
  marshal ({1, 'a', "Foo", "Foo"}), [1, 'a'.ord, 0, 3, "Foo", 1]
end
