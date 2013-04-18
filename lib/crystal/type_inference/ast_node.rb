module Crystal
  class ASTNode
    attr_accessor :type
    attr_accessor :dependencies
    attr_accessor :type_filters

    def set_type(type)
      @type = type
    end

    def type=(type)
      return if type.nil? || @type.object_id == type.object_id

      set_type(type)
      notify_observers
    end

    def real_type
      if dependencies && dependencies.length == 1
        dependencies[0].real_type
      else
        @type
      end
    end

    def map_type(type)
      type
    end

    def bind_to(node)
      @dependencies ||= []
      @dependencies << node
      node.add_observer self

      return unless node.type

      if @dependencies.length == 1 || !@type
        new_type = node.type
      else
        new_type = Type.merge(@type, node.type)
      end
      return if @type.object_id == new_type.object_id
      set_type(map_type(new_type))
      @dirty = true
      propagate
    end

    def add_observer(observer, func = :update)
      @observers ||= []
      @observers << [observer, func]
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
        new_type = Type.merge(@type, from.type)
      end

      return if @type.object_id == new_type.object_id
      set_type(map_type new_type)
      @dirty = true
    end

    def propagate
      if @dirty
        @dirty = false
        notify_observers
      end
    end

    def raise(message, inner = nil)
      Kernel::raise Crystal::TypeException.for_node(self, message, inner)
    end
  end

  class PointerOf
    attr_accessor :mod

    def map_type(type)
      mod.lookup_generic_type(mod.pointer, [type])
    end
  end
end