module XML
  struct Attributes
    include Enumerable(Attribute)

    def initialize(@node)
    end

    def length
      count = 0
      each_ptr do |ptr|
        count += 1
      end
      count
    end

    def [](index : Int)
      length = self.length

      index += length if index < 0

      unless 0 <= index < length
        raise IndexOutOfBounds.new
      end

      i = 0
      each_ptr do |ptr|
        if i == index
          return Attribute.new(ptr)
        end
        i += 1
      end

      raise IndexOutOfBounds.new
    end

    def [](name : String)
      self[name]? || raise MissingKey.new("Missing attribute: #{name}")
    end

    def []?(name : String)
      each_ptr do |ptr|
        if String.new(ptr.value.name) == name
          return Attribute.new(ptr)
        end
      end
      nil
    end

    def each
      each_ptr do |ptr|
        yield Attribute.new(ptr)
      end
    end

    private def each_ptr
      return unless @node.is_a?(Element)

      ptr = @node.to_unsafe as LibXML::Node*
      props = ptr.value.properties as LibXML::NodeCommon*

      until props.nil?
        yield props
        props = props.value.next as LibXML::NodeCommon*
      end
    end
  end
end
