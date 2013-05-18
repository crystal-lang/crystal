module Crystal
  class ASTNode
    attr_accessor :type
    attr_accessor :dependencies
    attr_accessor :type_filters
    attr_accessor :freeze_type

    def set_type(type)
      if @freeze_type
        raise "type must be #{@type}, not #{type}", nil, Crystal::FrozenTypeException
      end
      @type = type
    end

    def type=(type)
      return if type.nil? || @type.type_id == type.type_id

      set_type(type)
      notify_observers
    end

    def real_type
      if dependencies && dependencies.length == 1 && !dependencies[0].eql?(self)
        dependencies[0].real_type
      else
        @type
      end
    end

    def map_type(type)
      type
    end

    def bind_to(*nodes)
      @dependencies ||= []
      @dependencies.concat nodes
      nodes.each { |node| node.add_observer self }

      if @dependencies.length == 1
        new_type = nodes[0].type
      else
        new_type = Type.merge *@dependencies.map(&:type)
      end
      return if @type.type_id == new_type.type_id
      set_type(map_type(new_type))
      @dirty = true
      propagate
    end

    def unbind_from(*nodes)
      return unless @dependencies

      nodes.each do |node|
        idx = @dependencies.index { |d| d.equal?(node) }
        @dependencies.delete_at(idx) if idx
        node.remove_observer self
      end
    end

    def add_observer(observer, func = :update)
      @observers ||= []
      @observers << [observer, func]
    end

    def remove_observer(observer)
      return unless @observers
      idx = @observers.index { |o| o.equal?(observer) }
      @observers.delete_at(idx) if idx
    end

    def notify_observers
      return unless @observers
      @observers.each do |observer, func|
        observer.send func, self
      end
      @observers.each do |observer, func|
        observer.propagate
      end
    end

    def update(from)
      return if !from.type || @type.equal?(from.type)

      if @type.nil? || dependencies.length == 1
        new_type = from.type
      else
        new_type = Type.merge *@dependencies.map(&:type)
      end

      return if @type.type_id == new_type.type_id
      set_type(map_type new_type)
      @dirty = true
    end

    def propagate
      if @dirty
        @dirty = false
        notify_observers
      end
    end

    def raise(message, inner = nil, exception_type = Crystal::TypeException)
      Kernel::raise exception_type.for_node(self, message, inner)
    end
  end

  class PointerOf
    attr_accessor :mod

    def map_type(type)
      mod.pointer_of(type)
    end
  end

  class ArrayLiteral
    attr_accessor :mod
    attr_accessor :new_generic_class

    def map_type(type)
      if of
        type
      else
        mod.array_of(type)
      end
    end

    def set_type(type)
      super
      new_generic_class.type = type.metaclass unless of
    end
  end

  class HashLiteral
    attr_accessor :mod
    attr_accessor :new_generic_class

    def map_type(type)
      if of_key
        type
      else
        mod.hash_of(@dependencies[0].type, @dependencies[1].type)
      end
    end

    def set_type(type)
      super
      new_generic_class.type = type.metaclass unless of_key
    end
  end

  class RangeLiteral
    attr_accessor :mod
    attr_accessor :new_generic_class

    def map_type(type)
      mod.range_of(@dependencies[0].type, @dependencies[1].type)
    end

    def set_type(type)
      super
      new_generic_class.type = type.metaclass
    end
  end
end