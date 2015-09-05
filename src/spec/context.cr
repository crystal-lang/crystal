module Spec
  # :nodoc:
  abstract class Context
  end

  # :nodoc:
  record Result, kind, description, file, line, exception

  # :nodoc:
  class RootContext < Context
    getter before_each
    getter after_each

    def initialize
      @results = {
        success: [] of Result,
        fail: [] of Result,
        error: [] of Result,
        pending: [] of Result,
      }
      @before_each = [] of ->
      @after_each = [] of ->
    end

    def parent
      nil
    end

    def succeeded
      @results[:fail].empty? && @results[:error].empty?
    end

    def self.report(kind, full_description, file, line, ex = nil)
      result = Result.new(kind, full_description, file, line, ex)
      @@contexts_stack.last.report(result)
    end

    def report(result)
      Spec.formatter.report(result)
      @results[result.kind] << result
    end

    def self.print_results(elapsed_time)
      @@instance.print_results(elapsed_time)
    end

    def self.succeeded
      @@instance.succeeded
    end

    def print_results(elapsed_time)
      Spec.formatter.finish

      pendings = @results[:pending]
      unless pendings.empty?
        puts
        puts "Pending:"
        pendings.each do |pending|
          puts Spec.color("  #{pending.description}", :pending)
        end
      end

      failures = @results[:fail]
      errors = @results[:error]

      failures_and_errors = failures + errors
      unless failures_and_errors.empty?
        puts
        puts "Failures:"
        failures_and_errors.each_with_index do |fail, i|
          if ex = fail.exception
            puts
            puts "  #{i + 1}) #{fail.description}"
            if ex.is_a?(AssertionFailed)
              source_line = Spec.read_line(ex.file, ex.line)
              if source_line
                puts Spec.color("     Failure/Error: #{source_line.strip}", :error)
              end
            end
            puts

            ex.to_s.split("\n").each do |line|
              print "       "
              puts Spec.color(line, :error)
            end
            unless ex.is_a?(AssertionFailed)
              ex.backtrace.each do |trace|
                print "       "
                puts Spec.color(trace, :error)
              end
            end

            if ex.is_a?(AssertionFailed)
              puts
              puts "     # #{Spec.relative_file(ex.file)}:#{ex.line}".colorize.cyan
            end
          end
        end
      end

      puts

      success = @results[:success]
      total = pendings.length + failures.length + errors.length + success.length

      final_status = case
                     when (failures.length + errors.length) > 0 then :fail
                     when pendings.length > 0                   then :pending
                     else                                            :success
                     end

      total_seconds = elapsed_time.total_seconds
      if total_seconds < 1
        puts "Finished in #{elapsed_time.total_milliseconds.round(2)} milliseconds"
      elsif total_seconds < 60
        puts "Finished in #{total_seconds.round(2)} seconds"
      else
        minutes = elapsed_time.minutes
        seconds = elapsed_time.seconds
        puts "Finished in #{minutes}:#{seconds < 10 ? "0" : ""}#{seconds} minutes"
      end
      puts Spec.color("#{total} examples, #{failures.length} failures, #{errors.length} errors, #{pendings.length} pending", final_status)

      unless failures_and_errors.empty?
        puts
        puts "Failed examples:"
        puts
        failures_and_errors.each do |fail|
          print "crystal spec #{Spec.relative_file(fail.file)}:#{fail.line}".colorize.red
          puts " # #{fail.description}".colorize.cyan
        end
      end
    end

    @@instance = RootContext.new
    @@contexts_stack = [@@instance] of Context

    def self.describe(description, file, line)
      describe = Spec::NestedContext.new(description, file, line, @@contexts_stack.last)
      @@contexts_stack.push describe
      Spec.formatter.push describe
      yield describe
      Spec.formatter.pop
      @@contexts_stack.pop
    end

    def self.matches?(description, pattern, line)
      @@contexts_stack.any?(&.matches?(pattern, line)) || description =~ pattern
    end

    def self.before_each(&block)
      @@contexts_stack.last.before_each << block
    end

    def self.after_each(&block)
      @@contexts_stack.last.after_each << block
    end

    def self.run_before_each_hooks
      @@contexts_stack.map(&.before_each).flatten().each(&.call)
    end

    def self.run_after_each_hooks
      @@contexts_stack.map(&.after_each).flatten().each(&.call)
    end

    def matches?(pattern, line)
      false
    end
  end

  # :nodoc:
  class NestedContext < Context
    getter parent
    getter description
    getter file
    getter line
    getter before_each
    getter after_each

    def initialize(@description : String, @file, @line, @parent)
      @before_each = [] of ->
      @after_each = [] of ->
    end

    def report(result)
      @parent.report Result.new(result.kind, "#{@description} #{result.description}", result.file, result.line, result.exception)
    end

    def matches?(pattern, line)
      @description =~ pattern || @line == line
    end
  end
end
