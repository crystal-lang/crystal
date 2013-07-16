module Crystal
  class ASTNode
    attr_accessor :type
    attr_accessor :dependencies

    def set_type(type)
      @type = type
    end

    def type=(type)
      return if type.nil? || @type.object_id == type.object_id

      @type = type
      notify_observers
    end

    def bind_to(node)
      @dependencies ||= [] of ASTNode
      @dependencies << node
      node.add_observer self

      return unless node.type

      if (@dependencies && @dependencies.length == 1) || !@type
        new_type = node.type
      else
        new_type = Type.merge(@type, node.type)
      end
      return if @type.object_id == new_type.object_id
      set_type(new_type)
      @dirty = true
      propagate
    end

    def add_observer(observer)
      @observers ||= [] of ASTNode
      @observers << observer
    end

    def notify_observers
      if @observers
        @observers.each do |observer|
          observer.update self
        end
        @observers.each do |observer|
          observer.propagate
        end
      end
    end

    def update(from)
      return if @type.object_id == from.type.object_id

      if @type.nil? || (@dependencies && @dependencies.length == 1)
        new_type = from.type
      else
        new_type = Type.merge @type, from.type
      end

      return if @type.object_id == new_type.object_id
      set_type(new_type)
      @dirty = true
    end

    def propagate
      if @dirty
        @dirty = false
        notify_observers
      end
    end
  end
end