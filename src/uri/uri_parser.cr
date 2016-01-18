# Parser based on https://url.spec.whatwg.org/
class URIParser
  property uri

  macro cor(method)
    return {{method}}
  end

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
      cor parse_scheme
    else
      cor parse_no_scheme
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
          @ptr += 1
          cor parse_path_or_authority
        else
          # greatly deviates from spec
          @uri.opaque = String.new(@input + @ptr + 1)
          cor nil
        end
      else
        @ptr = 0
        cor parse_no_scheme
      end
    end
  end

  def parse_path_or_authority
    if c === '/'
      @ptr += 1
      cor parse_authority
    else
      cor nil # parse_path
    end
  end

  def parse_no_scheme
    case c
    when '#'
      cor parse_fragment
    else
      cor parse_relative
    end
  end

  def parse_authority
    @ptr += 1
    start = @ptr
    loop do
      if c === '@'
        @ptr = start
        cor parse_userinfo
      elsif end_of_host?
        @ptr = start
        cor parse_host
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
        cor parse_host
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
    loop do
      if c === ':' && !bracket_flag
        @uri.host = from_input(start)
        @ptr += 1
        cor parse_port
      elsif end_of_host?
        @uri.host = from_input(start)
        cor parse_path
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
        @uri.port = (start...@ptr).inject(0) do |memo, i|
          (memo * 10) + (@input[i] - '0'.ord)
        end
        # todo speical scheme ports
        cor parse_path
      else
        # todo failure
        break
      end
    end
  end

  def parse_relative
    case c
    when '\0'
      cor nil
    when '/'
      cor parse_relative_slash
    when '?'
      cor parse_query
    when '#'
      cor parse_fragment
    else
      cor parse_path
    end
  end

  def parse_relative_slash
    if @input[@ptr + 1] === '/'
      @ptr += 1
      cor parse_authority
    else
      cor parse_path
    end
  end

  def parse_path
    start = @ptr
    loop do
      case c
      when '\0'
        @uri.path = from_input(start)
        cor nil
      when '?'
        @uri.path = from_input(start)
        cor parse_query
      when '#'
        @uri.path = from_input(start)
        cor parse_fragment
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
        cor nil
      when '#'
        @uri.query = from_input(start)
        cor parse_fragment
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
        cor nil
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
