require "html"

module Spec
  # :nodoc:
  class JUnitFormatter < Formatter
    @started_at = Time.utc

    @results = [] of Spec::Result
    @summary = {} of Symbol => Int32

    def report(result)
      current = @summary[result.kind]? || 0
      @summary[result.kind] = current + 1
      @results << result
    end

    def finish(elapsed_time, aborted)
      io = @io
      io.puts %(<?xml version="1.0"?>)
      io << %(<testsuite tests=") << @results.size
      io << %(" skipped=") << (@summary[:pending]? || 0)
      io << %(" errors=") << (@summary[:error]? || 0)
      io << %(" failures=") << (@summary[:fail]? || 0)
      io << %(" time=") << elapsed_time.total_seconds
      io << %(" timestamp=") << @started_at.to_rfc3339
      io << %(" hostname=") << System.hostname
      io << %(">)

      io.puts

      @results.each { |r| write_report(r, io) }

      io << %(</testsuite>)
      io.close
    end

    def self.file(output_path : Path)
      Dir.mkdir_p(output_path.dirname)
      file = File.new(output_path, "w")
      JUnitFormatter.new(file)
    end

    private def escape_xml_attr(value)
      String.build do |io|
        reader = Char::Reader.new(value)
        while reader.has_next?
          case current_char = reader.current_char
          when .control?
            current_char.to_s.inspect_unquoted(io)
          else
            current_char.to_s(io)
          end
          reader.next_char
        end
      end
    end

    # -------- private utility methods
    private def write_report(result, io)
      io << %(  <testcase file=")
      HTML.escape(result.file, io)
      io << %(" classname=")
      HTML.escape(classname(result), io)
      io << %(" name=")
      HTML.escape(escape_xml_attr(result.description), io)

      if elapsed = result.elapsed
        io << %(" time=")
        io << elapsed.total_seconds
      end

      if tag = inner_content_tag(result.kind)
        io.puts %(">)

        if (exception = result.exception) && result.kind != :pending
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
      when :error   then "error"
      when :fail    then "failure"
      when :pending then "skipped"
      end
    end

    private def write_inner_content(tag, exception, io)
      io << "    <" << tag

      if message = exception.message
        io << %( message=")
        HTML.escape(message, io)
        io << '"'
      end
      if tag == :error
        io << %( type=")
        io << exception.class.name
        io << '"'
      end
      io << '>'

      if backtrace = exception.backtrace?
        HTML.escape(backtrace.join('\n'), io)
      end

      io << "</" << tag << ">\n"
    end

    private def classname(result)
      path = Path[result.file].expand
      path.to_s
        .lchop(Dir.current)
        .rchop(path.extension)
        .gsub(File::SEPARATOR, '.')
        .strip('.')
    end
  end
end
