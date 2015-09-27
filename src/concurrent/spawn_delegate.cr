module Concurrent
  struct SpawnDelegate(T)
    def initialize @object : T
    end

    macro method_missing(name, args, block)
      spawn do
        @object.{{name.id}}({{*args}}) {{block}}
      end
    end
  end
end
