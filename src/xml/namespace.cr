class XML::Namespace
  getter document : Node

  def initialize(@document : Node, @ns : LibXML::NS*)
  end

  # See `Object#hash(hasher)`
  def_hash object_id

  def href : String?
    @ns.value.href ? String.new(@ns.value.href) : nil
  end

  def object_id : UInt64
    @ns.address
  end

  def prefix : String?
    @ns.value.prefix ? String.new(@ns.value.prefix) : nil
  end

  def to_s(io : IO) : Nil
    io << "#<XML::Namespace:0x"
    object_id.to_s(io, 16)

    if prefix = self.prefix
      io << " prefix="
      prefix.inspect(io)
    end

    if href = self.href
      io << " href="
      href.inspect(io)
    end

    io << '>'
  end

  def inspect(io : IO) : Nil
    to_s io
  end
end
