module Spec
  # :nodoc:
  abstract class Formatter
    def initialize(@io : IO = STDOUT)
    end

    def push(context)
    end

    def pop
    end

    def before_example(description)
    end

    def report(result)
    end

    def finish
    end

    def print_results(elapsed_time : Time::Span, aborted : Bool)
    end
  end

  # :nodoc:
  class DotFormatter < Formatter
    def report(result)
      @io << Spec.color(LETTERS[result.kind], result.kind)
      @io.flush
    end

    def finish
      @io.puts
    end

    def print_results(elapsed_time : Time::Span, aborted : Bool)
      Spec::RootContext.print_results(elapsed_time, aborted)
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
      self.class.print_indent(@io, @indent)
    end

    def self.print_indent(io, indent)
      indent.times { io << "  " }
    end

    def before_example(description)
      @items.each &.print(@io)
      print_indent
      @io << description
      @last_description = description
    end

    def report(result)
      @io << '\r'
      print_indent
      @io.puts Spec.color(@last_description, result.kind)
    end

    def print_results(elapsed_time : Time::Span, aborted : Bool)
      Spec::RootContext.print_results(elapsed_time, aborted)
    end
  end

  @@formatters = [Spec::DotFormatter.new] of Spec::Formatter

  # :nodoc:
  def self.formatters
    @@formatters
  end

  def self.override_default_formatter(formatter)
    @@formatters[0] = formatter
  end

  def self.add_formatter(formatter)
    @@formatters << formatter
  end
end
