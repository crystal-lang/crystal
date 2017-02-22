require "colorize"
require "./scheduler"
require "../signal"

module ThreadLog
  @@mutex = Thread::Mutex.new
  @@colors = %i(red green yellow blue magenta cyan light_red light_green light_yellow)
  @@thread_colors = {} of Scheduler => Symbol

  def self.tlog(msg, *args)
    begin
      sched = Thread.current.scheduler
      msg = "#{sched} - #{msg}"
      thread_color = ThreadLog.color_for(sched)
      LibC.printf "#{msg.colorize(thread_color)}\n", *args
    rescue
      LibC.printf "Failure logging. Maybe current thread's scheduler isn't initialized yet?\n", *args
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
