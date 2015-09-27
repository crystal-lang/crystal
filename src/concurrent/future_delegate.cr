module Concurrent
  struct FutureDelegate(T)
    def initialize @object : T, @run_immediately = true, @delay = 0
    end

    macro method_missing(name, args, block)
      Future.new run_immediately: @run_immediately, delay: @delay do
        @object.{{name.id}}({{*args}}) {{block}}
      end
    end
  end
end
