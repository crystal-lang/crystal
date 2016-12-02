require "xml"

module Spec
  # :nodoc:
  class JUnitFormatter < Formatter
    @output : IO
    @results = [] of Spec::Result
    @summary = {} of Symbol => Int32

    def initialize(@output)
    end

    def push(context)
    end

    def pop
    end

    def before_example(description)
    end

    def report(result)
      current = @summary[result.kind]? || 0
      @summary[result.kind] = current + 1
      @results << result
    end

    def finish
      io = @output
      io << "<testsuite tests=\"#{@results.size}\" \
                        errors=\"#{@summary[:error]? || 0}\" \
                        failed=\"#{@summary[:fail]? || 0}\">\n"

      @results.each { |r| write_report(r, io) }

      io << "</testsuite>"
      io.close
    end

    def self.file(output_dir)
      Dir.mkdir_p(output_dir)
      output_file_path = File.join(output_dir, "output.xml")
      file = File.new(output_file_path, "w")
      JUnitFormatter.new(file)
    end

    # -------- private utility methods
    private def write_report(result, io)
      io << "<testcase file=\"#{result.file}\" classname=\"#{classname(result)}\" name=\"#{XML.escape(result.description)}\">\n"

      if (has_inner_content(result.kind))
        tag = inner_content_tag(result.kind)
        ex = result.exception
        if ex
          write_inner_content(tag, ex, io)
        else
          io << "<#{tag} />\n"
        end
      end

      io << "</testcase>\n"
    end

    private def has_inner_content(kind)
      kind == :fail || kind == :error
    end

    private def inner_content_tag(kind)
      case kind
      when :error
        :error
      when :fail
        :failure
      end
    end

    private def write_inner_content(tag, exception, io)
      m = exception.message
      if m
        io << "<#{tag} message=\"#{XML.escape(m)}\">"
      else
        io << "<#{tag}>"
      end
      backtrace = exception.backtrace? || ([] of String)
      io << XML.escape(backtrace.join("\n"))
      io << "</#{tag}>\n"
    end

    private def classname(result)
      result.file.sub(%r{\.[^/.]+\Z}, "").gsub("/", ".").gsub(/\A\.+|\.+\Z/, "")
    end
  end
end
