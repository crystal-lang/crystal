require "./node"

module XML
  class Attribute < Node
    def inspect(io)
      io << "#<" << self.class.name << ":0x"
      object_id.to_s(16, io)

      io << " name="
      name.inspect(io)

      io << " value="
      content.inspect(io)

      io << ">"
      io
    end
  end
end
