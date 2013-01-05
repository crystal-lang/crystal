module Crystal
  class Dispatch < ASTNode
    attr_accessor :name
    attr_accessor :obj
    attr_accessor :args
    attr_accessor :calls

    def initialize_for_call(call)
      @name = call.name
      @obj = call.obj && call.obj.type
      @args = call.args.map(&:type)
      @calls = {}
      recalculate(call)
    end

    def recalculate_for_call(call)
      @name = call.name
      @obj = call.obj && call.obj.type
      @args = call.args.map(&:type)
      recalculate(call)
    end

    def recalculate(call)
      for_each_obj do |obj_type|
        for_each_args do |arg_types|
          call_key = [obj_type.object_id, arg_types.map(&:object_id)]
          next if @calls[call_key]

          subcall = Call.new(obj_type ? Var.new('%self', obj_type) : nil, name, arg_types.map.with_index { |arg_type, i| Var.new("%arg#{i}", arg_type) })
          subcall.mod = call.mod
          subcall.parent_visitor = call.parent_visitor
          subcall.scope = call.scope
          subcall.location = call.location
          subcall.name_column_number = call.name_column_number
          subcall.block = call.block.clone
          subcall.block.accept call.parent_visitor if subcall.block
          subcall.recalculate
          self.bind_to subcall
          @calls[call_key] = subcall
        end
      end
    end

    def simplify
      return if @simplified
      new_calls = {}
      @calls.values.each do |call|
        new_calls[[(call.obj ? call.obj.type : nil).object_id] + call.args.map { |arg| arg.type.object_id }] = call
      end
      @calls = new_calls
      @simplified = true
    end

    def for_each_obj(&block)
      if @obj
        @obj.each &block
      else
        yield nil
      end
    end

    def for_each_args(args = @args, arg_types = [], index = 0, &block)
      if index == args.count
        yield arg_types
      else
        args[index].each do |arg_type|
          arg_types[index] = arg_type
          for_each_args(args, arg_types, index + 1, &block)
        end
      end
    end

    def accept_children(visitor)
      @calls.values.each do |call|
        call.accept visitor
      end
    end

    def to_s
      "#<Dispatch: #{@calls.length} calls>"
    end
  end
end