module Spec
  # :nodoc:
  abstract class Formatter
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
  end

  # :nodoc:
  class DotFormatter < Formatter
    def report(result)
      print Spec.color(LETTERS[result.kind], result.kind)
    end

    def finish
      puts
    end
  end

  # :nodoc:
  class VerboseFormatter < Formatter
    class Item
      def initialize(@indent : Int32, @description : String)
        @printed = false
      end

      def print
        return if @printed
        @printed = true

        VerboseFormatter.print_indent(@indent)
        puts @description
      end
    end

    def initialize
      @indent = 0
      @last_description = ""
      @items = [] of Item
    end

    def push(context)
      @items << Item.new(@indent, context.description)
      @indent += 1
    end

    def pop
      @items.pop
      @indent -= 1
    end

    def print_indent
      self.class.print_indent(@indent)
    end

    def self.print_indent(indent)
      indent.times { print "  " }
    end

    def before_example(description)
      @items.each &.print
      print_indent
      print description
      @last_description = description
    end

    def report(result)
      print '\r'
      print_indent
      puts Spec.color(@last_description, result.kind)
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
