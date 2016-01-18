require "../uri"

class URI
  property non_relative_flag
end

# Parser based on https://url.spec.whatwg.org/
class URIParser
  property uri

  SPECIAL_SCHEME = Set{"ftp", "file", "gopher", "http", "https", "ws", "wss"}

  macro cor(method)
    return {{method}}
  end

  def initialize(input)
    @uri = URI.new
    @input = input.strip.to_unsafe
    @state = :scheme_start
    @ptr = 0
  end

  def c
    @input[@ptr]
  end

  def run
    parse_scheme_start
  end

  def special_scheme?
    SPECIAL_SCHEME.includes? @uri.scheme
  end

  def parse_scheme_start
    if alpha?
      cor parse_scheme
    else
      # #parse_no_scheme
      cor nil
    end
  end

  def parse_scheme
    start = @ptr
    loop do
      if alpha? || numeric? || c === '-' || c === '.' || c === '+'
        @ptr += 1
      elsif c === ':'
        @uri.scheme = String.new(@input + start, @ptr - start)
        # todo file and other special cases
        if @input[@ptr + 1] === '/'
          @ptr += 1
          cor parse_path_or_authority
        else
          @uri.non_relative_flag = true
          @uri.path = ""
          # parse_non_relative_path
        end

        break
      else
        # parse_no_scheme
        @ptr = 0
        break
      end
    end
  end

  def parse_path_or_authority
    if c === '/'
      @ptr += 1
      cor parse_authority
    else
      # parse_path
    end
  end

  def parse_authority
    @ptr += 1
    start = @ptr
    loop do
      if c === '@'
        # todo
      elsif end_of_host?
        @ptr = start
        cor parse_host
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
        # todo if url is special and buffer empty fail
        @uri.host = String.new(@input + start, @ptr - start)
        cor parse_port
      elsif end_of_host?
        # todo if url is special and buffer empty fail
        # todo host parsing buffer
        @uri.host = String.new(@input + start, @ptr - start)
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

  def parse_path
    start = @ptr
    loop do
      case c
      when '\0'
        @uri.path = String.new(@input + start, @ptr - start)
        cor nil
      when '?'
        @uri.path = String.new(@input + start, @ptr - start)
        cor parse_query
      when '#'
        @uri.path = String.new(@input + start, @ptr - start)
        cor parse_fragment
      else
        @ptr += 1
      end
    end
  end

  def parse_query
    start = @ptr
    loop do
      case c
      when '\0'
        @uri.query = String.new(@input + start, @ptr - start)
        cor nil
      when '#'
        @uri.query = String.new(@input + start, @ptr - start)
        cor parse_fragment
      else
        @ptr += 1
      end
    end
  end

  def parse_fragment
    start = @ptr
    loop do
      case c
      when '\0'
        @uri.fragment = String.new(@input + start, @ptr - start)
        cor nil
      else
        @ptr += 1
      end
    end
  end

  private def alpha?
    ('a'.ord <= c && c <= 'z'.ord) ||
      ('A'.ord <= c && c <= 'Z'.ord)
  end

  private def numeric?
    '0'.ord <= c && c <= '9'.ord
  end

  private def end_of_host?
    c === '\0' || c === '/' || c === '?' || c === '#' || (special_scheme? && c === '\\')
  end
end
