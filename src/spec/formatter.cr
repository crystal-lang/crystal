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
    @ident : Int32
    @last_description : String

    def initialize
      @ident = 0
      @last_description = ""
    end

    def push(context)
      print_ident
      puts context.description
      @ident += 1
    end

    def pop
      @ident -= 1
    end

    def print_ident
      @ident.times { print "  " }
    end

    def before_example(description)
      print_ident
      print description
      @last_description = description
    end

    def report(result)
      print '\r'
      print_ident
      puts Spec.color(@last_description, result.kind)
    end
  end

  @@formatters = [] of Spec::Formatter
  @@formatters << Spec::DotFormatter.new

  # :nodoc:
  def self.formatters
    @@formatters
  end
end
