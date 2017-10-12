module Crystal
  class ProgressTracker
    # FIXME: This assumption is not always true
    STAGES        = 13
    STAGE_PADDING = 34

    property? stats = false
    property? progress = false

    getter current_stage = 1
    getter current_stage_name : String?
    getter stage_progress = 0
    getter stage_progress_total : Int32?

    def stage(name)
      @current_stage_name = name

      print_stats
      print_progress

      time_start = Time.monotonic
      retval = yield
      time_taken = Time.monotonic - time_start

      print_stats(time_taken)
      print_progress

      @current_stage += 1
      @stage_progress = 0
      @stage_progress_total = nil

      retval
    end

    def clear
      return unless @progress
      print " " * (STAGE_PADDING + 5)
      print "\r"
    end

    def print_stats(time_taken = nil)
      return unless @stats

      justified_name = "#{current_stage_name}:".ljust(STAGE_PADDING)
      if time_taken
        memory_usage_mb = GC.stats.heap_size / 1024.0 / 1024.0
        memory_usage_str = " (%7.2fMB)" % {memory_usage_mb} if true # display_memory?
        puts "#{justified_name} #{time_taken}#{memory_usage_str}"
      else
        print "#{justified_name}\r" unless @progress
      end
    end

    def print_progress
      return unless @progress

      if stage_progress_total = @stage_progress_total
        progress = " [#{@stage_progress}/#{stage_progress_total}]"
      end

      stage_name = @current_stage_name.try(&.ljust(STAGE_PADDING))
      print "[#{@current_stage}/#{STAGES}]#{progress} #{stage_name}\r"
    end

    def stage_progress=(@stage_progress)
      print_progress
    end

    def stage_progress_total=(@stage_progress_total)
      print_progress
    end
  end
end
