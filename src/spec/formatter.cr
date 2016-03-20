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
    @indent : Int32
    @last_description : String
    @items : Array(Item)

    class Item
      @indent : Int32
      @description : String
      @printed : Bool

      def initialize(@indent, @description)
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

  @@formatters : Array(Spec::Formatter)
  @@formatters = [] of Spec::Formatter
  @@formatters << Spec::DotFormatter.new

  # :nodoc:
  def self.formatters
    @@formatters
  end
end
