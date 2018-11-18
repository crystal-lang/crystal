require "html"

module Spec
  # :nodoc:
  class JUnitFormatter < Formatter
    @results = [] of Spec::Result
    @summary = {} of Symbol => Int32

    def report(result)
      current = @summary[result.kind]? || 0
      @summary[result.kind] = current + 1
      @results << result
    end

    def finish
      io = @io
      io.puts %(<?xml version="1.0"?>)
      io << %(<testsuite tests=") << @results.size
      io << %(" errors=") << (@summary[:error]? || 0)
      io << %(" failures=") << (@summary[:fail]? || 0) << %(">)

      io.puts

      @results.each { |r| write_report(r, io) }

      io << %(</testsuite>)
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
      io << %(  <testcase file=")
      HTML.escape(result.file, io)
      io << %(" classname=")
      HTML.escape(classname(result), io)
      io << %(" name=")
      HTML.escape(result.description, io)

      if tag = inner_content_tag(result.kind)
        io.puts %(">)

        if exception = result.exception
          write_inner_content(tag, exception, io)
        else
          io << "    <" << tag << "/>\n"
        end
        io.puts "  </testcase>"
      else
        io.puts %("/>)
      end
    end

    private def inner_content_tag(kind)
      case kind
      when :error then "error"
      when :fail  then "failure"
      end
    end

    private def write_inner_content(tag, exception, io)
      io << "    <" << tag

      if message = exception.message
        io << %( message=")
        HTML.escape(message, io)
        io << '"'
      end
      io << '>'

      if backtrace = exception.backtrace?
        HTML.escape(backtrace.join('\n'), io)
      end

      io << "</" << tag << ">\n"
    end

    private def classname(result)
      result.file.sub(%r{\.[^/.]+\Z}, "").gsub("/", ".").gsub(/\A\.+|\.+\Z/, "")
    end
  end
end
