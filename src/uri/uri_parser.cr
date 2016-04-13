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

    # overridden in specs to test step transitions
    macro step(method)
      return {{method}}
    end

    @input : UInt8*

    def initialize(input)
      @uri = URI.new
      @input = input.strip.to_unsafe
      @ptr = 0
    end

    def c
      @input[@ptr]
    end

    def run
      parse_scheme_start
      self
    end

    def parse_scheme_start
      if alpha?
        step parse_scheme
      else
        step parse_no_scheme
      end
    end

    def parse_scheme
      start = @ptr
      loop do
        if alpha? || numeric? || c === '-' || c === '.' || c === '+'
          @ptr += 1
        elsif c === ':'
          @uri.scheme = from_input(start)
          if @input[@ptr + 1] === '/'
            @ptr += 2
            step parse_path_or_authority
          else
            # greatly deviates from spec as described, but is correct behavior
            @uri.opaque = String.new(@input + @ptr + 1)
            step nil
          end
        else
          @ptr = 0
          step parse_no_scheme
        end
      end
    end

    def parse_path_or_authority
      if c === '/'
        step parse_authority
      else
        @ptr -= 1
        step parse_path
      end
    end

    def parse_no_scheme
      case c
      when '#'
        step parse_fragment
      else
        step parse_relative
      end
    end

    def parse_authority
      @ptr += 1
      start = @ptr
      loop do
        if c === '@'
          @ptr = start
          step parse_userinfo
        elsif end_of_host?
          @ptr = start
          step parse_host
        else
          @ptr += 1
        end
      end
    end

    def parse_userinfo
      start = @ptr
      password_flag = false
      loop do
        if c === '@'
          if password_flag
            @uri.password = URI.unescape(from_input(start))
          else
            @uri.user = URI.unescape(from_input(start))
          end
          @ptr += 1
          step parse_host
        elsif c === ':'
          @uri.user = URI.unescape(from_input(start))
          password_flag = true
          @ptr += 1
          start = @ptr
        else
          @ptr += 1
        end
      end
    end

    def parse_host
      start = @ptr
      bracket_flag = false
      step parse_path if c === '/'
      loop do
        if c === ':' && !bracket_flag
          @uri.host = from_input(start)
          @ptr += 1
          step parse_port
        elsif end_of_host?
          @uri.host = from_input(start)
          step parse_path
        else
          bracket_flag = true if c === '['
          bracket_flag = false if c === ']'
          @ptr += 1
        end
      end
    end

    def parse_port
      start = @ptr
      loop do
        if numeric?
          @ptr += 1
        elsif end_of_host?
          @uri.port = (start...@ptr).reduce(0) do |memo, i|
            (memo * 10) + (@input[i] - '0'.ord)
          end
          step parse_path
        else
          raise URI::Error.new("Invalid URI: bad port at character #{@ptr}")
        end
      end
    end

    def parse_relative
      case c
      when '\0'
        step nil
      when '/'
        step parse_relative_slash
      when '?'
        step parse_query
      when '#'
        step parse_fragment
      else
        step parse_path
      end
    end

    def parse_relative_slash
      if @input[@ptr + 1] === '/'
        @ptr += 1
        step parse_authority
      else
        step parse_path
      end
    end

    def parse_path
      start = @ptr
      loop do
        case c
        when '\0'
          @uri.path = from_input(start)
          step nil
        when '?'
          @uri.path = from_input(start)
          step parse_query
        when '#'
          @uri.path = from_input(start)
          step parse_fragment
        else
          @ptr += 1
        end
      end
    end

    def parse_query
      @ptr += 1
      start = @ptr
      loop do
        case c
        when '\0'
          @uri.query = from_input(start)
          step nil
        when '#'
          @uri.query = from_input(start)
          step parse_fragment
        else
          @ptr += 1
        end
      end
    end

    def parse_fragment
      @ptr += 1
      start = @ptr
      loop do
        case c
        when '\0'
          @uri.fragment = from_input(start)
          step nil
        else
          @ptr += 1
        end
      end
    end

    private def from_input(start)
      String.new(@input + start, @ptr - start)
    end

    private def alpha?
      ('a'.ord <= c && c <= 'z'.ord) ||
        ('A'.ord <= c && c <= 'Z'.ord)
    end

    private def numeric?
      '0'.ord <= c && c <= '9'.ord
    end

    private def end_of_host?
      c === '\0' || c === '/' || c === '?' || c === '#'
    end
  end
end
