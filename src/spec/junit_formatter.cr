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

      XML.build(io, indent: 2) do |xml|
        attributes = {
          tests:  @results.size,
          errors: @summary[:error]? || 0,
          failed: @summary[:fail]? || 0,
        }

        xml.element("testsuite", attributes) do
          @results.each { |r| write_report(r, xml) }
        end
      end
    ensure
      io.try &.close
    end

    def self.file(output_dir)
      Dir.mkdir_p(output_dir)
      output_file_path = File.join(output_dir, "output.xml")
      file = File.new(output_file_path, "w")
      JUnitFormatter.new(file)
    end

    private def write_report(result, xml)
      attributes = {
        file:      result.file,
        classname: classname(result),
        name:      result.description,
      }

      xml.element("testcase", attributes) do
        if tag = inner_content_tag(result.kind)
          if ex = result.exception
            write_inner_content(tag, ex, xml)
          else
            xml.element(tag)
          end
        end
      end
    end

    private def inner_content_tag(kind)
      case kind
      when :error
        "error"
      when :fail
        "failure"
      end
    end

    private def write_inner_content(tag, exception, xml)
      if message = exception.message
        attributes = {message: message}
      else
        attributes = NamedTuple.new
      end

      xml.element(tag, attributes) do
        backtrace = exception.backtrace? || Array(String).new
        xml.text backtrace.join('\n')
      end
    end

    private def classname(result)
      result.file.sub(%r{\.[^/.]+\Z}, "").gsub("/", ".").gsub(/\A\.+|\.+\Z/, "")
    end
  end
end
