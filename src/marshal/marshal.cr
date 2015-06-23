class Marshal(T)
  def self.save(obj : T, io = StringIO.new)
    ValueMarshaler(T).save(obj, Marshaler.new(io))
    io
  end

  def self.load(io)
    ValueMarshaler(T).load(Unmarshaler.new(io))
  end
end

class Marshaler
  def initialize(@io)
    @classes = {} of String => Int32
    @references = {} of UInt64 => Int32
  end

  def write_int(value : UInt8)
    @io.write_byte(value)
  end

  def write_int(value)
    bytes = [] of UInt8
    loop do
      byte = (value & 0x7f).to_u8
      value >>= 7
      bytes << byte
      break if value == 0
    end
    while byte = bytes.pop?
      byte |= 0x80_u8 if bytes.any?
      @io.write_byte byte
    end
  end

  MASK64MSB = 0xff00000000000000

  def write_float(value : Float64)
    int_value = (pointerof(value) as UInt64*).value
    sizeof(Float64).times do
      @io.write_byte ((int_value & MASK64MSB) >> 56).to_u8
      int_value <<= 8
    end
  end

  def write_bytes(value : Slice(UInt8))
    @io.write(value)
  end

  def write_string(value : String)
    write_int(value.bytesize)
    write_bytes(value.to_slice)
  end

  def put_class(value : Class)
    if class_id = @classes[value.name]?
      class_id.save(self)
    else
      @classes[value.name] = @classes.size + 1
      0.save(self)
      write_string(value.name)
    end
  end

  def put_reference(value : Reference)
    if oid = @references[value.object_id]?
      oid.save(self)
      true
    else
      0.save(self)
      @references[value.object_id] = @references.size + 1
      false
    end
  end
end

class Unmarshaler
  def initialize(@io)
    @classes = {} of Int32 => String
    @references = {} of Int32 => Void*
  end

  def read_int
    value = 0_u64
    loop do
      byte = read_byte
      value <<= 7
      value |= (byte & 0x7f_u8)
      break if (byte & 0x80_u8) == 0
    end
    value
  end

  def read_float
    value = 0_u64
    sizeof(Float64).times do
      value <<= 8
      value |= read_byte
    end
    (pointerof(value) as Float64*).value
  end

  def read_byte
    @io.read_byte || raise "Unexpected EOF"
  end

  def read_bytes(slice : Slice(UInt8))
    @io.read_fully(slice)
  end

  def read_string
    bytesize = Int32.load(self)
    String.new(bytesize) do |buffer|
      read_bytes(Slice.new(buffer, bytesize))
      {bytesize, 0}
    end
  end

  def get_class(*classes : Class)
    class_id = Int32.load(self)
    if class_id == 0
      class_name = read_string
      @classes[@classes.size + 1] = class_name
    else
      class_name = @classes[class_id]
    end

    classes.find { |c| c.name == class_name } || raise "Unexpected class '#{class_name}'"
  end

  def get_reference
    oid = Int32.load(self)
    if oid == 0
      Pointer(Void).null
    else
      @references[oid.to_i]
    end
  end

  def save_reference(value : Reference)
    @references[@references.size + 1] = value as Void*
  end
end

module InstanceVariableMarshaler

  protected macro def unmarshal_instance_variables(input) : Nil
    {% for ivar in @type.instance_vars %}
      @{{ivar.id}} = ValueMarshaler(typeof(@{{ivar.id}})).load(input)
    {% end %}
    nil
  end

end

class ValueMarshaler(T)
  def self.save(value, output)
    {% if T.union? %}
      output.put_class(value.class)
    {% end %}
    value.save(output)
  end

  def self.load(input)
    {% if T.union? %}
      input.get_class({{ *T.union_types.map(&.name) }}).load(input)
    {% else %}
      T.load(input)
    {% end %}
  end
end

require "./*"


