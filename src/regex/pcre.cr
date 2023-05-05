require "./lib_pcre"

# :nodoc:
module Regex::PCRE
  def self.version : String
    String.new(LibPCRE.version)
  end

  class_getter version_number : {Int32, Int32} = begin
    version = self.version
    dot = version.index('.') || raise RuntimeError.new("Invalid libpcre2 version")
    space = version.index(' ', dot) || raise RuntimeError.new("Invalid libpcre2 version")
    {version.byte_slice(0, dot).to_i, version.byte_slice(dot + 1, space - dot - 1).to_i}
  end

  private def initialize(*, _source source, _options @options)
    # PCRE's pattern must have their null characters escaped
    source = source.gsub('\u{0}', "\\0")
    @source = source

    @re = LibPCRE.compile(@source, pcre_compile_options(options) | LibPCRE::UTF8 | LibPCRE::DUPNAMES | LibPCRE::UCP, out errptr, out erroffset, nil)
    raise ArgumentError.new("#{String.new(errptr)} at #{erroffset}") if @re.null?
    @extra = LibPCRE.study(@re, LibPCRE::STUDY_JIT_COMPILE, out studyerrptr)
    if @extra.null? && studyerrptr
      {% unless flag?(:interpreted) %}
        LibPCRE.free.call @re.as(Void*)
      {% end %}
      raise ArgumentError.new("#{String.new(studyerrptr)}")
    end
    LibPCRE.full_info(@re, nil, LibPCRE::INFO_CAPTURECOUNT, out @captures)
  end

  private def pcre_compile_options(options)
    flag = 0
    Regex::CompileOptions.each do |option|
      if options.includes?(option)
        flag |= case option
                when .ignore_case?       then LibPCRE::CASELESS
                when .multiline?         then LibPCRE::DOTALL | LibPCRE::MULTILINE
                when .dotall?            then LibPCRE::DOTALL
                when .extended?          then LibPCRE::EXTENDED
                when .anchored?          then LibPCRE::ANCHORED
                when .dollar_endonly?    then LibPCRE::DOLLAR_ENDONLY
                when .firstline?         then LibPCRE::FIRSTLINE
                when .utf_8?             then LibPCRE::UTF8
                when .no_utf_check?      then LibPCRE::NO_UTF8_CHECK
                when .dupnames?          then LibPCRE::DUPNAMES
                when .ucp?               then LibPCRE::UCP
                when .endanchored?       then raise ArgumentError.new("Regex::Option::ENDANCHORED is not supported with PCRE")
                when .match_invalid_utf? then raise ArgumentError.new("Regex::Option::MATCH_INVALID_UTF is not supported with PCRE")
                else
                  raise "Unreachable"
                end
        options &= ~option
      end
    end

    # Unnamed values are explicitly used PCRE options, just pass them through:
    flag |= options.value

    flag
  end

  def self.supports_compile_flag?(options)
    !options.endanchored? && !options.match_invalid_utf?
  end

  private def pcre_match_options(options)
    flag = 0
    Regex::Options.each do |option|
      if options.includes?(option)
        flag |= case option
                when .ignore_case?    then raise ArgumentError.new("Invalid regex option IGNORE_CASE for `pcre_exec`")
                when .multiline?      then raise ArgumentError.new("Invalid regex option MULTILINE for `pcre_exec`")
                when .dotall?         then raise ArgumentError.new("Invalid regex option DOTALL for `pcre_exec`")
                when .extended?       then raise ArgumentError.new("Invalid regex option EXTENDED for `pcre_exec`")
                when .anchored?       then LibPCRE::ANCHORED
                when .dollar_endonly? then raise ArgumentError.new("Invalid regex option DOLLAR_ENDONLY for `pcre_exec`")
                when .firstline?      then raise ArgumentError.new("Invalid regex option FIRSTLINE for `pcre_exec`")
                when .utf_8?          then raise ArgumentError.new("Invalid regex option UTF_8 for `pcre_exec`")
                when .no_utf_check?   then LibPCRE::NO_UTF8_CHECK
                when .dupnames?       then raise ArgumentError.new("Invalid regex option DUPNAMES for `pcre_exec`")
                when .ucp?            then raise ArgumentError.new("Invalid regex option UCP for `pcre_exec`")
                when .endanchored?    then raise ArgumentError.new("Regex::Option::ENDANCHORED is not supported with PCRE")
                else
                  raise "Unreachable"
                end
        options &= ~option
      end
    end

    # Unnamed values are explicitly used PCRE options, just pass them through:
    flag |= options.value

    flag
  end

  private def pcre_match_options(options : Regex::MatchOptions)
    flag = 0
    Regex::MatchOptions.each do |option|
      if options.includes?(option)
        flag |= case option
                when .anchored?     then LibPCRE::ANCHORED
                when .endanchored?  then raise ArgumentError.new("Regex::Option::ENDANCHORED is not supported with PCRE")
                when .no_jit?       then raise ArgumentError.new("Regex::Option::NO_JIT is not supported with PCRE")
                when .no_utf_check? then LibPCRE::NO_UTF8_CHECK
                else
                  raise "Unreachable"
                end
        options &= ~option
      end
    end

    # Unnamed values are explicitly used PCRE options, just pass them through:
    flag |= options.value

    flag
  end

  def self.supports_match_flag?(options)
    !options.endanchored? && !options.no_jit?
  end

  def finalize
    LibPCRE.free_study @extra
    {% unless flag?(:interpreted) %}
      LibPCRE.free.call @re.as(Void*)
    {% end %}
  end

  protected def self.error_impl(source)
    re = LibPCRE.compile(source, LibPCRE::UTF8 | LibPCRE::DUPNAMES, out errptr, out erroffset, nil)
    if re
      {% unless flag?(:interpreted) %}
        LibPCRE.free.call re.as(Void*)
      {% end %}
      nil
    else
      "#{String.new(errptr)} at #{erroffset}"
    end
  end

  private def name_table_impl
    LibPCRE.full_info(@re, @extra, LibPCRE::INFO_NAMECOUNT, out name_count)
    LibPCRE.full_info(@re, @extra, LibPCRE::INFO_NAMEENTRYSIZE, out name_entry_size)
    table_pointer = Pointer(UInt8).null
    LibPCRE.full_info(@re, @extra, LibPCRE::INFO_NAMETABLE, pointerof(table_pointer).as(Pointer(Int32)))
    name_table = table_pointer.to_slice(name_entry_size*name_count)

    lookup = Hash(Int32, String).new

    name_count.times do |i|
      capture_offset = i * name_entry_size
      capture_number = ((name_table[capture_offset].to_u16 << 8)).to_i32 | name_table[capture_offset + 1]

      name_offset = capture_offset + 2
      checked = name_table[name_offset, name_entry_size - 3]
      name = String.new(checked.to_unsafe)

      lookup[capture_number] = name
    end

    lookup
  end

  private def capture_count_impl
    LibPCRE.full_info(@re, @extra, LibPCRE::INFO_CAPTURECOUNT, out capture_count)
    capture_count
  end

  private def match_impl(str, byte_index, options)
    ovector_size = (@captures + 1) * 3
    ovector = Pointer(Int32).malloc(ovector_size)
    if internal_matches?(str, byte_index, options, ovector, ovector_size)
      Regex::MatchData.new(self, @re, str, byte_index, ovector, @captures)
    end
  end

  private def matches_impl(str, byte_index, options)
    internal_matches?(str, byte_index, options, nil, 0)
  end

  # Calls `pcre_exec` C function, and handles returning value.
  private def internal_matches?(str, byte_index, options, ovector, ovector_size)
    ret = LibPCRE.exec(@re, @extra, str, str.bytesize, byte_index, pcre_match_options(options), ovector, ovector_size)

    return true if ret >= 0

    case error = LibPCRE::Error.new(ret)
    when .nomatch?
      return false
    when .badutf8_offset?
      raise ArgumentError.new("Regex match error: bad offset into UTF string")
    when .badutf8?
      raise ArgumentError.new("Regex match error: UTF-8 error")
    else
      raise Regex::Error.new("Regex match error: #{error}")
    end
  end

  module MatchData
    # :nodoc:
    def initialize(@regex : ::Regex, @code : LibPCRE::Pcre, @string : String, @pos : Int32, @ovector : Int32*, @group_size : Int32)
    end

    private def byte_range(n, &)
      n += size if n < 0
      range = Range.new(@ovector[n * 2], @ovector[n * 2 + 1], exclusive: true)
      if range.begin < 0 || range.end < 0
        yield n
      else
        range
      end
    end

    private def fetch_impl(group_name : String, &)
      max_start = -1
      match = nil
      exists = false
      each_named_capture_number(group_name) do |n|
        exists = true
        start = byte_range(n) { nil }.try(&.begin) || next
        if start > max_start
          max_start = start
          match = self[n]?
        end
      end
      if match
        match
      else
        yield exists
      end
    end

    private def each_named_capture_number(group_name, &)
      name_entry_size = LibPCRE.get_stringtable_entries(@code, group_name, out first, out last)
      return if name_entry_size < 0

      while first <= last
        capture_number = (first[0].to_u16 << 8) | first[1].to_u16
        yield capture_number

        first += name_entry_size
      end

      nil
    end
  end
end
