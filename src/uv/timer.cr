module UV
  class Timer
    def initialize(loop = Loop::DEFAULT)
      LibUV.timer_init(loop, out @timer)
      @timer.handle.data = self as Void*
    end

    def start(timeout, repeat = 0_u64, &@callback : (Timer, Int32) ->)
      LibUV.timer_start(self, ->(timer, status) {
        this = timer.value.handle.data as Timer
        if cb = this.@callback
          cb.call(this, status)
        end
      }, timeout.to_u64, repeat.to_u64)
    end

    def stop
      LibUV.timer_stop(self)
    end

    def again
      LibUV.timer_again(self)
    end

    def to_unsafe
      pointerof(@timer)
    end
  end
end
