require "./item"

module Spec
  # Base type for `ExampleGroup`.
  abstract class Context
    # All the children, which can be `describe`/`context` or `it`
    getter children = [] of ExampleGroup | Example

    protected abstract def cli : CLI

    def randomize(randomizer)
      children.each do |child|
        child.randomize(randomizer) if child.is_a?(ExampleGroup)
      end
      children.shuffle!(randomizer)
    end

    protected def internal_run
      run_before_all_hooks
      children.each &.run
      run_after_all_hooks
    end

    protected def before_each(&block)
      (@before_each ||= [] of ->) << block
    end

    protected def run_before_each_hooks
      @before_each.try &.each &.call
    end

    protected def after_each(&block)
      (@after_each ||= [] of ->) << block
    end

    protected def run_after_each_hooks
      @after_each.try &.reverse_each &.call
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
      internal_run_around_each_hooks(procsy)
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

  # :nodoc:
  enum Status
    Success
    Fail
    Error
    Pending

    def color : Colorize::Color
      case self
      in Success then Colorize::ColorANSI::Green
      in Fail    then Colorize::ColorANSI::Red
      in Error   then Colorize::ColorANSI::Red
      in Pending then Colorize::ColorANSI::Yellow
      end
    end

    def letter : Char
      case self
      in Success then '.'
      in Fail    then 'F'
      in Error   then 'E'
      in Pending then '*'
      end
    end
  end

  # :nodoc:
  record Result,
    kind : Status,
    description : String,
    file : String,
    line : Int32,
    elapsed : Time::Span?,
    exception : Exception?

  # :nodoc:
  class CLI
    getter root_context : RootContext { RootContext.new(self) }
    property current_context : Context { root_context }
  end

  # :nodoc:
  #
  # The root context is the main interface that the spec DSL interacts with.
  class RootContext < Context
    @results : Hash(Status, Array(Result))

    protected getter cli : CLI

    def results_for(status : Status)
      @results[status]
    end

    def initialize(@cli : CLI)
      @results = Status.values.to_h { |status| {status, [] of Result} }
    end

    def run
      print_order_message(cli.stdout)

      internal_run
    end

    def report(status : Status, full_description, file, line, elapsed = nil, ex = nil)
      result = Result.new(status, full_description, file, line, elapsed, ex)

      report_formatters result

      @results[status] << result
    end

    def report_formatters(result)
      cli.formatters.each(&.report(result))
    end

    def succeeded
      results_for(:fail).empty? && results_for(:error).empty?
    end

    def finish(elapsed_time, aborted = false)
      cli.formatters.each(&.finish(elapsed_time, aborted))
      if cli.formatters.any?(&.should_print_summary?)
        print_summary(cli.stdout, elapsed_time, aborted)
      end
    end

    def print_summary(io : IO, elapsed_time, aborted = false)
      pendings = results_for(:pending)
      unless pendings.empty?
        io.puts
        io.puts "Pending:"
        pendings.each do |pending|
          io.puts cli.colorize("  #{pending.description}", :pending)
        end
      end

      failures = results_for(:fail)
      errors = results_for(:error)

      cwd = Dir.current

      failures_and_errors = failures + errors
      unless failures_and_errors.empty?
        io.puts
        io.puts "Failures:"
        failures_and_errors.each_with_index do |fail, i|
          if ex = fail.exception
            io.puts
            io.puts "#{(i + 1).to_s.rjust(3, ' ')}) #{fail.description}"

            if ex.is_a?(SpecError)
              source_line = Spec.read_line(ex.file, ex.line)
              if source_line
                io.puts cli.colorize("     Failure/Error: #{source_line.strip}", :error)
              end
            end
            io.puts

            message = ex.is_a?(SpecError) ? ex.to_s : ex.inspect_with_backtrace
            message.split('\n') do |line|
              io.print "       "
              io.puts cli.colorize(line, :error)
            end

            if ex.is_a?(SpecError)
              io.puts
              io.puts cli.colorize("     # #{Path[ex.file].relative_to(cwd)}:#{ex.line}", :comment)
            end
          end
        end
      end

      if cli.slowest
        io.puts
        results = results_for(:success) + results_for(:fail)
        top_n = results.sort_by { |res| -res.elapsed.not_nil!.to_f }[0..cli.slowest.not_nil!]
        top_n_time = top_n.sum &.elapsed.not_nil!.total_seconds
        percent = (top_n_time * 100) / elapsed_time.total_seconds
        io.puts "Top #{cli.slowest} slowest examples (#{top_n_time.humanize} seconds, #{percent.round(2)}% of total time):"
        top_n.each do |res|
          io.puts "  #{res.description}"
          res_elapsed = res.elapsed.not_nil!.total_seconds.humanize
          io.puts "    #{res_elapsed.colorize.bold.toggle(cli.color?)} seconds #{Path[res.file].relative_to(cwd)}:#{res.line}"
        end
      end

      io.puts

      success = results_for(:success)
      total = pendings.size + failures.size + errors.size + success.size

      final_status = case
                     when aborted                           then Status::Error
                     when (failures.size + errors.size) > 0 then Status::Fail
                     when pendings.size > 0                 then Status::Pending
                     else                                        Status::Success
                     end

      io.puts "Aborted!".colorize.red.toggle(cli.color?) if aborted
      io.puts "Finished in #{Spec.to_human(elapsed_time)}"
      io.puts cli.colorize("#{total} examples, #{failures.size} failures, #{errors.size} errors, #{pendings.size} pending", final_status)
      io.puts cli.colorize("Only running `focus: true`", :focus) if cli.focus?

      unless failures_and_errors.empty?
        io.puts
        io.puts "Failed examples:"
        io.puts
        failures_and_errors.each do |fail|
          io.print cli.colorize("crystal spec #{Path[fail.file].relative_to(cwd)}:#{fail.line}", :error)
          io.puts cli.colorize(" # #{fail.description}", :comment)
        end
      end

      print_order_message(io)
    end

    def print_order_message(io : IO)
      if randomizer_seed = cli.randomizer_seed
        io.puts cli.colorize("Randomized with seed: #{randomizer_seed}", :order)
      end
    end

    def describe(description, file, line, end_line, focus, tags, &block)
      cli.focus = true if focus

      context = Spec::ExampleGroup.new(cli.current_context, description, file, line, end_line, focus, tags)
      cli.current_context.children << context

      old_context = cli.current_context
      cli.current_context = context
      begin
        block.call
      ensure
        cli.current_context = old_context
      end
    end

    def it(description, file, line, end_line, focus, tags, &block)
      add_example(description, file, line, end_line, focus, tags, block)
    end

    def pending(description, file, line, end_line, tags)
      add_example(description, file, line, end_line, false, tags, nil)
    end

    private def add_example(description, file, line, end_line, focus, tags, block)
      check_nesting_spec(file, line) do
        cli.focus = true if focus
        cli.current_context.children <<
          Example.new(cli.current_context, description, file, line, end_line, focus, tags, block)
      end
    end

    @spec_nesting = false

    def check_nesting_spec(file, line, &block)
      raise NestingSpecError.new("Can't nest `it` or `pending`", file, line) if @spec_nesting

      @spec_nesting = true
      begin
        yield
      ensure
        @spec_nesting = false
      end
    end

    protected def around_all(&block : ExampleGroup::Procsy ->)
      raise "Can't call `around_all` outside of a describe/context"
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
    def cli : CLI
      @parent.cli
    end

    # :nodoc:
    def run
      cli.formatters.each(&.push(self))

      ran = run_around_all_hooks(ExampleGroup::Procsy.new(self) { internal_run })
      ran || internal_run

      cli.formatters.each(&.pop)
    end

    protected def report(status : Status, description, file, line, elapsed = nil, ex = nil)
      parent.report status, "#{@description} #{description}", file, line, elapsed, ex
    end

    protected def run_before_each_hooks
      @parent.run_before_each_hooks
      super
    end

    protected def run_after_each_hooks
      super
      @parent.run_after_each_hooks
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
  end
end

require "./example_group/procsy"
