require "./item"

module Spec
  # Base type for `ExampleGroup`.
  abstract class Context
    # All the children, which can be `describe`/`context` or `it`
    getter children = [] of ExampleGroup | Example

    def randomize(randomizer)
      children.each do |child|
        child.randomize(randomizer) if child.is_a?(ExampleGroup)
      end
      children.shuffle!(randomizer)
    end
  end

  # :nodoc:
  record Result,
    kind : Symbol,
    description : String,
    file : String,
    line : Int32,
    elapsed : Time::Span?,
    exception : Exception?

  # :nodoc:
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
      Spec.formatters.each(&.finish(elapsed_time, aborted))
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

      if randomizer_seed = Spec.randomizer_seed
        puts Spec.color("Randomized with seed: #{randomizer_seed}", :order)
      end

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

    def describe(description, file, line, end_line, focus, tags, &block)
      Spec.focus = true if focus

      context = Spec::ExampleGroup.new(@@current_context, description, file, line, end_line, focus, tags)
      @@current_context.children << context

      old_context = @@current_context
      @@current_context = context
      begin
        block.call
      ensure
        @@current_context = old_context
      end
    end

    def it(description, file, line, end_line, focus, tags, &block)
      add_example(description, file, line, end_line, focus, tags, block)
    end

    def pending(description, file, line, end_line, focus, tags)
      add_example(description, file, line, end_line, focus, tags, nil)
    end

    private def add_example(description, file, line, end_line, focus, tags, block)
      check_nesting_spec(file, line) do
        Spec.focus = true if focus
        @@current_context.children <<
          Example.new(@@current_context, description, file, line, end_line, focus, tags, block)
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

    def before_each(&block)
      if @@current_context == self
        raise "Can't call `before_each` outside of a describe/context"
      end

      @@current_context.before_each(&block)
    end

    def run_before_each_hooks
      # Nothing
    end

    def after_each(&block)
      if @@current_context == self
        raise "Can't call `after_each` outside of a describe/context"
      end

      @@current_context.after_each(&block)
    end

    def run_after_each_hooks
      # Nothing
    end

    def before_all(&block)
      if @@current_context == self
        raise "Can't call `before_all` outside of a describe/context"
      end

      @@current_context.before_all(&block)
    end

    def after_all(&block)
      if @@current_context == self
        raise "Can't call `after_all` outside of a describe/context"
      end

      @@current_context.after_all(&block)
    end

    def around_each(&block : Example::Procsy ->)
      if @@current_context == self
        raise "Can't call `around_each` outside of a describe/context"
      end

      @@current_context.around_each(&block)
    end

    def run_around_each_hooks(procsy : Example::Procsy) : Bool
      false
    end

    def around_all(&block : ExampleGroup::Procsy ->)
      if @@current_context == self
        raise "Can't call `around_all` outside of a describe/context"
      end

      @@current_context.around_all(&block)
    end

    def run_around_all_hooks(procsy : ExampleGroup::Procsy) : Bool
      false
    end
  end

  # Represents a `describe` or `context`.
  class ExampleGroup < Context
    include Item

    def initialize(@parent : Context, @description : String,
                   @file : String, @line : Int32, @end_line : Int32,
                   @focus : Bool, tags)
      initialize_tags(tags)
    end

    # :nodoc:
    def run
      Spec.formatters.each(&.push(self))

      ran = run_around_all_hooks(ExampleGroup::Procsy.new(self) { internal_run })
      ran || internal_run

      Spec.formatters.each(&.pop)
    end

    protected def internal_run
      run_before_all_hooks
      children.each &.run
      run_after_all_hooks
    end

    protected def report(kind, description, file, line, elapsed = nil, ex = nil)
      parent.report kind, "#{@description} #{description}", file, line, elapsed, ex
    end

    protected def before_each(&block)
      (@before_each ||= [] of ->) << block
    end

    protected def run_before_each_hooks
      @parent.run_before_each_hooks
      @before_each.try &.each &.call
    end

    protected def after_each(&block)
      (@after_each ||= [] of ->) << block
    end

    protected def run_after_each_hooks
      @after_each.try &.reverse_each &.call
      @parent.run_after_each_hooks
    end

    protected def before_all(&block)
      (@before_all ||= [] of ->) << block
    end

    protected def run_before_all_hooks
      @before_all.try &.each &.call
    end

    protected def after_all(&block)
      (@after_all ||= [] of ->) << block
    end

    protected def run_after_all_hooks
      @after_all.try &.reverse_each &.call
    end

    protected def around_each(&block : Example::Procsy ->)
      (@around_each ||= [] of Example::Procsy ->) << block
    end

    protected def run_around_each_hooks(procsy : Example::Procsy) : Bool
      ran = @parent.run_around_each_hooks(Example::Procsy.new(procsy.example) do
        if @around_each
          # If we have around callbacks we execute them, and it will
          # eventually run the example
          internal_run_around_each_hooks(procsy)
        else
          # Otherwise we have to run the example now, because the parent
          # around hooks won't run it
          procsy.run
        end
      end)
      ran || internal_run_around_each_hooks(procsy)
    end

    protected def internal_run_around_each_hooks(procsy : Example::Procsy) : Bool
      around_each = @around_each
      return false unless around_each

      run_around_each_hook(around_each, procsy, 0)
      true
    end

    protected def run_around_each_hook(around_each, procsy, index) : Nil
      around_each[index].call(
        if index == around_each.size - 1
          # If we don't have any more hooks after this one, call the procsy
          procsy
        else
          # Otherwise, create a procsy that will invoke the next hook
          Example::Procsy.new(procsy.example) do
            run_around_each_hook(around_each, procsy, index + 1)
          end
        end
      )
    end

    protected def around_all(&block : ExampleGroup::Procsy ->)
      (@around_all ||= [] of ExampleGroup::Procsy ->) << block
    end

    protected def run_around_all_hooks(procsy : ExampleGroup::Procsy) : Bool
      around_all = @around_all
      return false unless around_all

      run_around_all_hook(around_all, procsy, 0)
      true
    end

    protected def run_around_all_hook(around_all, procsy, index) : Nil
      around_all[index].call(
        if index == around_all.size - 1
          # If we don't have any more hooks after this one, call the procsy
          procsy
        else
          # Otherwise, create a procsy that will invoke the next hook
          ExampleGroup::Procsy.new(procsy.example_group) do
            run_around_all_hook(around_all, procsy, index + 1)
          end
        end
      )
    end
  end
end

require "./example_group/procsy"
