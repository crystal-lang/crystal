module XML
  class Text < Node
    def inspect(io)
      io << "#<" << self.class.name << ":0x"
      object_id.to_s(16, io)
      io << " "
      content.inspect(io)
      io << ">"
      io
    end

    def name
      "text"
    end
  end
end
