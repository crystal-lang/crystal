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
    @at_flag = false
    @bracket_flag = false
    @ptr = 0
  end

  def c
    @input[@ptr]
  end

  def run
    parse_scheme_start
  end

  def reset_buffer
    @buffer = String::Builder.new
  end

  def special_scheme?
    SPECIAL_SCHEME.includes? @uri.scheme
  end

  def parse_scheme_start
    if alpha?
      cor parse_scheme
    else
      # #parse_no_scheme
    end
  end

  def alpha?
    ('a'.ord <= c && c <= 'z'.ord) ||
      ('A'.ord <= c && c <= 'Z'.ord)
  end

  def parse_scheme
    start = @ptr
    loop do
      if alpha? || c === '-' || c === '.' || c === '+'
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
      elsif c === '\0' || c === '/' || c === '?' || c === '#' || (special_scheme? && c === '\\')
        @ptr = start
        parse_host
        break
      else
        @ptr += 1
      end
    end
  end

  def parse_host
    start = @ptr
    loop do
      if c === ':' && @bracket_flag == false
        # todo if url is special and buffer empty fail
        @uri.host = String.new(@input + start, @ptr - start)
        break
        # @state = :port
      elsif c === '\0' || c === '/' || c === '?' || c === '#' || (special_scheme? && c === '\\')
        # todo if url is special and buffer empty fail
        # todo host parsing buffer
        @uri.host = String.new(@input + start, @ptr - start)
        break
        # parse_path
      else
        @bracket_flag = true if c === '['
        @bracket_flag = false if c === ']'
        @ptr += 1
      end
    end
  end
end
