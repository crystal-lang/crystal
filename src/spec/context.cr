module Spec
  abstract class Context
  end

  class RootContext < Context
    def initialize
      @results = {
        success: [] of Result,
        fail: [] of Result,
        error: [] of Result,
        pending: [] of Result,
      }
    end

    def parent
      nil
    end

    def succeeded
      @results[:fail].empty? && @results[:error].empty?
    end

    def self.report(kind, full_description, ex = nil)
      @@contexts_stack.last.report(kind, full_description, ex)
    end

    def report(kind, full_description, ex = nil)
      Spec.formatter.report(kind, full_description, ex)
      @results[kind] << Result.new(kind, full_description, ex)
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

      unless failures.empty? && errors.empty?
        puts
        puts "Failures:"
        (failures + errors).each_with_index do |fail, i|
          if ex = fail.exception
            puts
            puts "  #{i + 1}) #{fail.description}"
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

      puts "Finished in #{elapsed_time} seconds"
      puts Spec.color("#{total} examples, #{failures.length} failures, #{errors.length} errors, #{pendings.length} pending", final_status)
    end

    @@instance = RootContext.new
    @@contexts_stack = [@@instance] of Context

    def self.describe(description)
      describe = Spec::NestedContext.new(description, @@contexts_stack.last)
      @@contexts_stack.push describe
      Spec.formatter.push describe
      yield describe
      Spec.formatter.pop
      @@contexts_stack.pop
    end
  end

  class NestedContext < Context
    getter parent
    getter description

    def initialize(@description, @parent)
    end

    def report(kind, description, ex = nil)
      @parent.report(kind, "#{@description} #{description}", ex)
    end
  end
end
