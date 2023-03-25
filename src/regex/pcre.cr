require "./lib_pcre"

# :nodoc:
module Regex::PCRE
  private def initialize(*, _source source, _options @options)
    # PCRE's pattern must have their null characters escaped
    source = source.gsub('\u{0}', "\\0")
    @source = source

    @re = LibPCRE.compile(@source, pcre_options(options) | LibPCRE::UTF8 | LibPCRE::NO_UTF8_CHECK | LibPCRE::DUPNAMES | LibPCRE::UCP, out errptr, out erroffset, nil)
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

  private def pcre_options(options)
    flag = 0
    Regex::Options.each do |option|
      if options.includes?(option)
        flag |= case option
                when .ignore_case?    then LibPCRE::CASELESS
                when .multiline?      then LibPCRE::DOTALL | LibPCRE::MULTILINE
                when .dotall?         then LibPCRE::DOTALL
                when .extended?       then LibPCRE::EXTENDED
                when .anchored?       then LibPCRE::ANCHORED
                when .dollar_endonly? then LibPCRE::DOLLAR_ENDONLY
                when .firstline?      then LibPCRE::FIRSTLINE
                when .utf_8?          then LibPCRE::UTF8
                when .no_utf8_check?  then LibPCRE::NO_UTF8_CHECK
                when .dupnames?       then LibPCRE::DUPNAMES
                when .ucp?            then LibPCRE::UCP
                when .endanchored?    then raise ArgumentError.new("Regex::Option::ENDANCHORED is not supported with PCRE")
                when .no_jit?         then raise ArgumentError.new("Regex::Option::NO_JIT is not supported with PCRE")
                else
                  raise "unreachable"
                end
        options &= ~option
      end
    end

    unless options.none?
      {% if flag?(:use_pcre) %}
        # Unnamed values are explicitly used PCRE options, just pass them through:
        flag |= options.value
      {% else %}
        raise ArgumentError.new("Unknown Regex::Option value: #{options}")
      {% end %}
    end

    flag
  end

  def finalize
    LibPCRE.free_study @extra
    {% unless flag?(:interpreted) %}
      LibPCRE.free.call @re.as(Void*)
    {% end %}
  end

  protected def self.error_impl(source)
    re = LibPCRE.compile(source, LibPCRE::UTF8 | LibPCRE::NO_UTF8_CHECK | LibPCRE::DUPNAMES, out errptr, out erroffset, nil)
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
    ret = LibPCRE.exec(@re, @extra, str, str.bytesize, byte_index, pcre_options(options) | LibPCRE::NO_UTF8_CHECK, ovector, ovector_size)
    # TODO: when `ret < -1`, it means PCRE error. It should handle correctly.
    ret >= 0
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
