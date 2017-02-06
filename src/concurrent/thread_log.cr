require "colorize"

module ThreadLog
  @@mutex = Thread::Mutex.new
  @@colors = %i(red green yellow blue magenta cyan light_red light_green light_yellow)
  @@thread_colors = {} of LibC::PthreadT => Symbol

  def self.tlog(msg, *args)
    thread = LibC.pthread_self
    thread_color = ThreadLog.color_for(thread)
    msg = msg.colorize(thread_color)
    LibC.printf "#{msg}\n", *args
  end

  def self.color_for(thread)
    @@mutex.synchronize do
      thread_color = @@thread_colors[thread]?

      if !thread_color
        raise "There aren't enough colors to distinguish all threads in the log" if @@colors.empty?

        thread_color = @@colors.shift
        @@thread_colors[thread] = thread_color
      end

      thread_color
    end
  end
end
