require "./lib_pcre"

# :nodoc:
module Regex::PCRE
  # :nodoc:
  def initialize(*, _source source, _options @options)
    # PCRE's pattern must have their null characters escaped
    source = source.gsub('\u{0}', "\\0")
    @source = source

    @re = LibPCRE.compile(@source, (options | ::Regex::Options::UTF_8 | ::Regex::Options::NO_UTF8_CHECK | ::Regex::Options::DUPNAMES | ::Regex::Options::UCP), out errptr, out erroffset, nil)
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

  def finalize
    LibPCRE.free_study @extra
    {% unless flag?(:interpreted) %}
      LibPCRE.free.call @re.as(Void*)
    {% end %}
  end

  protected def self.error_impl(source)
    re = LibPCRE.compile(source, (Options::UTF_8 | Options::NO_UTF8_CHECK | Options::DUPNAMES), out errptr, out erroffset, nil)
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
      MatchData.new(self, @re, str, byte_index, ovector, @captures)
    end
  end

  private def matches_impl(str, byte_index, options)
    internal_matches?(str, byte_index, options, nil, 0)
  end

  # Calls `pcre_exec` C function, and handles returning value.
  private def internal_matches?(str, byte_index, options, ovector, ovector_size)
    ret = LibPCRE.exec(@re, @extra, str, str.bytesize, byte_index, (options | ::Regex::Options::NO_UTF8_CHECK), ovector, ovector_size)
    # TODO: when `ret < -1`, it means PCRE error. It should handle correctly.
    ret >= 0
  end
end
