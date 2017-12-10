# Based on rubysl-thread ruby gem implementation
# Copyright (c) 2013, Brian Shirai
# Licensed under the BSD 3-clause

# :nodoc:
class Thread
  # :nodoc:
  class Queue(T)
    class Error < Exception; end

    def initialize
      @que = Deque(T).new(16)
      @mutex = Thread::Mutex.new
      @resource = Thread::ConditionVariable.new
    end

    def push(item : T)
      @mutex.synchronize do
        @que.push(item)
        @resource.signal
      end
    end

    def pop(blocking = true)
      loop do
        @mutex.synchronize do
          if @que.empty?
            raise Error.new("queue is empty") unless blocking
            @resource.wait(@mutex)
          else
            item = @que.shift
            @resource.signal
            return item
          end
        end
      end
    end

    def clear
      @mutex.synchronize do
        @que.clear
      end
    end

    def empty?
      size == 0
    end

    def size
      @que.size
    end
  end
end
