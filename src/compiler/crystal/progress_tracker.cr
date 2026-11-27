require "./gc_log"
require "./process_memory"

module Crystal
  class ProgressTracker
    # FIXME: This assumption is not always true
    STAGES        = 14
    STAGE_PADDING = 34

    property? stats = false
    getter? gc_stats = false
    property? progress = false

    getter current_stage = 1
    getter current_stage_name : String?
    getter stage_progress = 0
    getter stage_progress_total : Int32?

    def stage(name, &)
      @current_stage_name = name

      print_stats
      print_progress

      time_start = Time.instant
      retval = yield
      time_taken = time_start.elapsed

      print_stats(time_taken)
      print_progress

      @current_stage += 1
      @stage_progress = 0
      @stage_progress_total = nil

      retval
    end

    def gc_stats=(@gc_stats : Bool) : Bool
      if gc_stats
        @stats = true
        GCLog.install
      end
      gc_stats
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
        print_collections if @gc_stats
        puts "#{justified_name} #{time_taken} (#{memory_usage})"
      else
        print "#{justified_name}\r" unless @progress
      end
    end

    private def print_collections : Nil
      dropped = GCLog.drain do |collection|
        before = collection.used_before
        after = collection.live_after
        freed = before > 0 ? (before.to_f64 - after) / before * 100 : 0.0
        label = "  GC ##{collection.number}".ljust(STAGE_PADDING)
        puts "#{label} #{collection.duration} %7.2f MB -> %7.2f MB (%4.1f%% freed)" % {
          megabytes(before), megabytes(after), freed,
        }
      end
      puts "  (#{dropped} more collections not shown)" if dropped > 0
    end

    private def memory_usage : String
      stats = GC.stats
      used = stats.heap_size &- stats.free_bytes
      usage = "heap in use #{format_megabytes(used)}, heap size #{format_megabytes(stats.heap_size)}"
      if process = ProcessMemory.current
        usage += ", process #{format_megabytes(process)}"
      end
      usage
    end

    private def format_megabytes(bytes : UInt64) : String
      "%7.2fMB" % {megabytes(bytes)}
    end

    private def megabytes(bytes : UInt64) : Float64
      bytes / 1024.0 / 1024.0
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
