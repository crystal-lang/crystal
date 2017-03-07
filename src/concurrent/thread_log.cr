require "colorize"
require "./scheduler"
require "../signal"

module ThreadLog
  @@mutex = Thread::Mutex.new
  @@colors = %i(red green yellow blue magenta cyan light_red light_green light_yellow)
  @@thread_colors = {} of Scheduler => Symbol

  def self.tlog(msg, *args)
    sched = Thread.current.scheduler?
    if sched
      msg = "#{sched.object_id} - #{msg}"
      thread_color = ThreadLog.color_for(sched)
      LibC.printf "#{msg.colorize(thread_color)}\n", *args
    else
      # No current scheduler, this is the EventLoop thread
      LibC.printf "EventLoop - #{msg}\n", *args
    end
  end

  def self.color_for(sched)
    @@mutex.synchronize do
      thread_color = @@thread_colors[sched]?

      if !thread_color
        raise "There aren't enough colors to distinguish all threads in the log" if @@colors.empty?

        thread_color = @@colors.shift
        @@thread_colors[sched] = thread_color
      end

      thread_color
    end
  end
end
