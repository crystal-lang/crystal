module Crystal
  class Poset
    attr_accessor :relation
    attr_accessor :layers

    def initialize(relation)
      @relation = relation
      @layers = []
    end

    def add(element)
      @layers.each_with_index do |layer, i|
        case compare(element, layer)
        when :above
          # next
        when :same
          layer.elements << element
          return
        when :below
          @layers.insert(i, Layer.new(element))
          return
        end
      end
      @layers << Layer.new(element)
    end

    def compare(element, layer)
      layer.elements.each do |layer_element|
        if relation.call(element, layer_element)
          return :below
        elsif relation.call(layer_element, element)
          return :above
        end
      end
      return :same
    end

    class Layer
      attr_accessor :elements

      def initialize(element)
        @elements = [element]
      end

      def to_s
        elements.inspect
      end
    end
  end
end


