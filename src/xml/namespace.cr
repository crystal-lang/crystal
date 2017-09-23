struct XML::Namespace
  getter document : Node

  def initialize(@document : Node, @ns : LibXML::NS*)
  end

  # See `Object#hash(hasher)`
  def_hash object_id

  def href
    @ns.value.href ? String.new(@ns.value.href) : nil
  end

  def object_id
    @ns.address
  end

  def prefix
    @ns.value.prefix ? String.new(@ns.value.prefix) : nil
  end

  def to_s(io)
    io << "#<XML::Namespace:0x"
    object_id.to_s(16, io)

    if prefix = self.prefix
      io << " prefix="
      prefix.inspect(io)
    end

    if href = self.href
      io << " href="
      href.inspect(io)
    end

    io << ">"
    io
  end

  def inspect(io)
    to_s io
  end
end
