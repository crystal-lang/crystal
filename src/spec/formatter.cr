module Spec
  # :nodoc:
  abstract class Formatter
    def initialize(@cli : CLI)
    end

    def push(context)
    end

    def pop
    end

    def before_example(description)
    end

    def report(result)
    end

    def finish(elapsed_time, aborted)
    end

    def should_print_summary?
      false
    end
  end

  # :nodoc:
  class DotFormatter < Formatter
    @count = 0
    @split = 0

    def initialize(*args)
      super

      if split = ENV["SPEC_SPLIT_DOTS"]?
        @split = split.to_i
      end
    end

    def report(result)
      @cli.stdout << @cli.colorize(result.kind.letter, result.kind)
      split_lines
      @cli.stdout.flush
    end

    private def split_lines
      return unless @split > 0
      if (@count += 1) >= @split
        @cli.stdout.puts
        @count = 0
      end
    end

    def finish(elapsed_time, aborted)
      @cli.stdout.puts
    end

    def should_print_summary?
      true
    end
  end

  # :nodoc:
  class VerboseFormatter < Formatter
    class Item
      def initialize(@indent : Int32, @description : String)
        @printed = false
      end

      def print(io)
        return if @printed
        @printed = true

        VerboseFormatter.print_indent(io, @indent)
        io.puts @description
      end
    end

    @indent = 0
    @last_description = ""
    @items = [] of Item

    def push(context)
      @items << Item.new(@indent, context.description)
      @indent += 1
    end

    def pop
      @items.pop
      @indent -= 1
    end

    def print_indent
      self.class.print_indent(@cli.stdout, @indent)
    end

    def self.print_indent(io, indent)
      indent.times { io << "  " }
    end

    def before_example(description)
      @items.each &.print(@cli.stdout)
      print_indent
      @cli.stdout << description
      @last_description = description
    end

    def report(result)
      @cli.stdout << '\r'
      print_indent
      @cli.stdout.puts @cli.colorize(@last_description, result.kind)
    end

    def should_print_summary?
      true
    end
  end

  # :nodoc:
  class CLI
    def formatters
      @formatters ||= [Spec::DotFormatter.new(self)] of Spec::Formatter
    end

    def override_default_formatter(formatter)
      formatters[0] = formatter
    end

    def add_formatter(formatter)
      formatters << formatter
    end
  end

  @[Deprecated("This is an internal API.")]
  def self.override_default_formatter(formatter)
    @@cli.override_default_formatter(formatter)
  end

  @[Deprecated("This is an internal API.")]
  def self.add_formatter(formatter)
    @@cli.add_formatter(formatter)
  end
end
