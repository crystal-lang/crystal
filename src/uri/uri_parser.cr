class URI
  # :nodoc:
  struct Parser
    # Parser is based on https://url.spec.whatwg.org/ .
    # Step names and variables are roughly the same as that document.
    # notable deviations from the spec
    #   does not parse windows slashes
    #   does not validate port < 2**16-1
    #   does not validate IPv4 or v6 hosts are valid
    #   ports greater than 2^16-1 are not errors
    property uri : URI

    @input : UInt8*

    def initialize(input : String)
      @uri = URI.new
      @input = input.strip.to_unsafe
      @ptr = 0
    end

    def c : UInt8
      @input[@ptr]
    end

    def run : self
      parse_scheme_start
      self
    end

    def parse_request_target : self
      parse_no_scheme
      self
    end

    private def parse_scheme_start : Nil
      if alpha?
        parse_scheme
      elsif c === '/' && @input[@ptr + 1] === '/'
        @ptr += 1
        @uri.host = ""
        parse_authority
      else
        parse_no_scheme
      end
    end

    private def parse_scheme : Nil
      start = @ptr
      loop do
        if alpha? || numeric? || c === '-' || c === '.' || c === '+'
          @ptr += 1
        elsif c === ':'
          @uri.scheme = from_input(start).downcase
          if @input[@ptr + 1] === '/'
            @ptr += 2
            return parse_path_or_authority
          else
            @ptr += 1
            return parse_path
          end
        else
          @ptr = 0
          return parse_no_scheme
        end
      end
    end

    private def parse_path_or_authority : Nil
      if c === '/'
        @uri.host = ""
        parse_authority
      else
        @ptr -= 1
        parse_path
      end
    end

    private def parse_no_scheme : Nil
      case c
      when '#'
        parse_fragment
      else
        parse_relative
      end
    end

    private def parse_authority : Nil
      @ptr += 1
      start = @ptr
      loop do
        if c === '@'
          @ptr = start
          return parse_userinfo
        elsif end_of_host?
          @ptr = start
          return parse_host
        else
          @ptr += 1
        end
      end
    end

    private def parse_userinfo : Nil
      start = @ptr
      password_flag = false
      loop do
        if c === '@'
          if password_flag
            @uri.password = URI.decode_www_form(from_input(start))
          else
            @uri.user = URI.decode_www_form(from_input(start))
          end
          @ptr += 1
          return parse_host
        elsif c === ':'
          @uri.user = URI.decode_www_form(from_input(start))
          password_flag = true
          @ptr += 1
          start = @ptr
        else
          @ptr += 1
        end
      end
    end

    private def parse_host : Nil
      start = @ptr
      bracket_flag = false
      return parse_path if c === '/'
      loop do
        if c === ':' && !bracket_flag
          @uri.host = URI.decode(from_input(start))
          @ptr += 1
          return parse_port
        elsif end_of_host?
          @uri.host = URI.decode(from_input(start))
          return parse_path
        else
          bracket_flag = true if c === '['
          bracket_flag = false if c === ']'
          @ptr += 1
        end
      end
    end

    private def parse_port : Nil
      start = @ptr
      loop do
        if numeric?
          @ptr += 1
        elsif end_of_host?
          unless start == @ptr
            @uri.port = (start...@ptr).reduce(0) do |memo, i|
              (memo * 10) + (@input[i] - '0'.ord)
            end
          end
          return parse_path
        else
          raise URI::Error.new("Invalid URI: bad port at character #{@ptr}")
        end
      end
    end

    private def parse_relative : Nil
      case c
      when '\0'
        nil
      when '?'
        parse_query
      when '#'
        parse_fragment
      else
        parse_path
      end
    end

    private def parse_path : Nil
      start = @ptr
      loop do
        case c
        when '\0'
          @uri.path = from_input(start)
          return nil
        when '?'
          @uri.path = from_input(start)
          return parse_query
        when '#'
          @uri.path = from_input(start)
          return parse_fragment
        else
          @ptr += 1
        end
      end
    end

    private def parse_query : Nil
      @ptr += 1
      start = @ptr
      loop do
        case c
        when '\0'
          @uri.query = from_input(start)
          return nil
        when '#'
          @uri.query = from_input(start)
          return parse_fragment
        else
          @ptr += 1
        end
      end
    end

    private def parse_fragment : Nil
      @ptr += 1
      start = @ptr
      loop do
        case c
        when '\0'
          @uri.fragment = from_input(start)
          return nil
        else
          @ptr += 1
        end
      end
    end

    private def from_input(start : Int32) : String
      String.new(@input + start, @ptr - start)
    end

    private def alpha? : Bool
      ('a'.ord <= c && c <= 'z'.ord) ||
        ('A'.ord <= c && c <= 'Z'.ord)
    end

    private def numeric? : Bool
      '0'.ord <= c && c <= '9'.ord
    end

    private def end_of_host? : Bool
      c === '\0' || c === '/' || c === '?' || c === '#'
    end
  end
end
