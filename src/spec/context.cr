require "./item"

module Spec
  # :nodoc:
  #
  # A context represents a `describe` or `context`.
  abstract class Context
    # All the children, which can be `describe`/`context` or `it`
    getter children = [] of NestedContext | Example
  end

  # :nodoc:
  record Result,
    kind : Symbol,
    description : String,
    file : String,
    line : Int32,
    elapsed : Time::Span?,
    exception : Exception?

  def self.root_context
    RootContext.instance
  end

  # :nodoc:
  #
  # The root context is the main interface that the spec DSL interacts with.
  class RootContext < Context
    class_getter instance = RootContext.new
    @@current_context : Context = @@instance

    def initialize
      @results = {
        success: [] of Result,
        fail:    [] of Result,
        error:   [] of Result,
        pending: [] of Result,
      }
    end

    def run
      children.each &.run
    end

    def report(kind, full_description, file, line, elapsed = nil, ex = nil)
      result = Result.new(kind, full_description, file, line, elapsed, ex)

      report_formatters result

      @results[result.kind] << result
    end

    def report_formatters(result)
      Spec.formatters.each(&.report(result))
    end

    def succeeded
      @results[:fail].empty? && @results[:error].empty?
    end

    def finish(elapsed_time, aborted = false)
      Spec.formatters.each(&.finish)
      Spec.formatters.each(&.print_results(elapsed_time, aborted))
    end

    def print_results(elapsed_time, aborted = false)
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
            puts "#{(i + 1).to_s.rjust(3, ' ')}) #{fail.description}"

            if ex.is_a?(SpecError)
              source_line = Spec.read_line(ex.file, ex.line)
              if source_line
                puts Spec.color("     Failure/Error: #{source_line.strip}", :error)
              end
            end
            puts

            message = ex.is_a?(SpecError) ? ex.to_s : ex.inspect_with_backtrace
            message.split('\n').each do |line|
              print "       "
              puts Spec.color(line, :error)
            end

            if ex.is_a?(SpecError)
              puts
              puts Spec.color("     # #{Spec.relative_file(ex.file)}:#{ex.line}", :comment)
            end
          end
        end
      end

      if Spec.slowest
        puts
        results = @results[:success] + @results[:fail]
        top_n = results.sort_by { |res| -res.elapsed.not_nil!.to_f }[0..Spec.slowest.not_nil!]
        top_n_time = top_n.sum &.elapsed.not_nil!.total_seconds
        percent = (top_n_time * 100) / elapsed_time.total_seconds
        puts "Top #{Spec.slowest} slowest examples (#{top_n_time} seconds, #{percent.round(2)}% of total time):"
        top_n.each do |res|
          puts "  #{res.description}"
          res_elapsed = res.elapsed.not_nil!.total_seconds.to_s
          if Spec.use_colors?
            res_elapsed = res_elapsed.colorize.bold
          end
          puts "    #{res_elapsed} seconds #{Spec.relative_file(res.file)}:#{res.line}"
        end
      end

      puts

      success = @results[:success]
      total = pendings.size + failures.size + errors.size + success.size

      final_status = case
                     when aborted                           then :error
                     when (failures.size + errors.size) > 0 then :fail
                     when pendings.size > 0                 then :pending
                     else                                        :success
                     end

      puts "Aborted!".colorize.red if aborted
      puts "Finished in #{Spec.to_human(elapsed_time)}"
      puts Spec.color("#{total} examples, #{failures.size} failures, #{errors.size} errors, #{pendings.size} pending", final_status)
      puts Spec.color("Only running `focus: true`", :focus) if Spec.focus?

      unless failures_and_errors.empty?
        puts
        puts "Failed examples:"
        puts
        failures_and_errors.each do |fail|
          print Spec.color("crystal spec #{Spec.relative_file(fail.file)}:#{fail.line}", :error)
          puts Spec.color(" # #{fail.description}", :comment)
        end
      end
    end

    def describe(description, file, line, end_line, focus, &block)
      Spec.focus = true if focus

      context = Spec::NestedContext.new(@@current_context, description, file, line, end_line, focus)
      @@current_context.children << context

      old_context = @@current_context
      @@current_context = context
      begin
        block.call
      ensure
        @@current_context = old_context
      end
    end

    def it(description, file, line, end_line, focus, &block)
      add_example(description, file, line, end_line, focus, block)
    end

    def pending(description, file, line, end_line, focus)
      add_example(description, file, line, end_line, focus, nil)
    end

    private def add_example(description, file, line, end_line, focus, block)
      check_nesting_spec(file, line) do
        Spec.focus = true if focus
        @@current_context.children <<
          Example.new(@@current_context, description, file, line, end_line, focus, block)
      end
    end

    @@spec_nesting = false

    def check_nesting_spec(file, line, &block)
      raise NestingSpecError.new("can't nest `it` or `pending`", file, line) if @@spec_nesting

      @@spec_nesting = true
      begin
        yield
      ensure
        @@spec_nesting = false
      end
    end
  end

  # :nodoc:
  class NestedContext < Context
    include Item

    def initialize(@parent : Context, @description : String,
                   @file : String, @line : Int32, @end_line : Int32,
                   @focus : Bool)
    end

    def run
      Spec.formatters.each(&.push(self))
      children.each &.run
      Spec.formatters.each(&.pop)
    end

    def report(kind, description, file, line, elapsed = nil, ex = nil)
      parent.report kind, "#{@description} #{description}", file, line, elapsed, ex
    end
  end
end
