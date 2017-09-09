require "./util"
require "colorize"

module Crystal
  abstract class Exception < ::Exception
    property? color = false

    @filename : String | VirtualFile | Nil

    def to_s(io)
      to_s_with_source(nil, io)
    end

    abstract def to_s_with_source(source, io)

    def to_json(json : JSON::Builder)
      json.array do
        to_json_single(json)
      end
    end

    def true_filename(filename = @filename) : String
      if filename.is_a? VirtualFile
        loc = filename.expanded_location
        if loc
          return true_filename loc.filename
        else
          return ""
        end
      else
        if filename
          return filename
        else
          return ""
        end
      end
    end

    def to_s_with_source(source)
      String.build do |io|
        to_s_with_source source, io
      end
    end

    def relative_filename(filename)
      Crystal.relative_filename(filename)
    end

    def colorize(obj)
      obj.colorize.toggle(@color)
    end

    def with_color
      ::with_color.toggle(@color)
    end

    def replace_leading_tabs_with_spaces(line)
      found_non_space = false
      line.gsub do |char|
        if found_non_space
          char
        elsif char == '\t'
          ' '
        elsif char.ascii_whitespace?
          char
        else
          found_non_space = true
          char
        end
      end
    end
  end

  class LocationlessException < Exception
    def to_s_with_source(source, io)
      io << @message
    end

    def append_to_s(source, io)
      io << @message
    end

    def has_location?
      false
    end

    def deepest_error_message
      @message
    end

    def to_json_single(json)
      json.object do
        json.field "message", @message
      end
    end
  end
end
