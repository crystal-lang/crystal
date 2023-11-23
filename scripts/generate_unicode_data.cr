#! /usr/bin/env crystal
#
# This script generates the file src/unicode/data.cr
# that contains compact representations of the UnicodeData.txt
# file from the unicode specification.

require "http/client"
require "ecr"
require "../src/compiler/crystal/formatter"

UCD_ROOT = "http://www.unicode.org/Public/#{Unicode::VERSION}/ucd/"

enum DecompositionType
  None
  Canonical
  Compatibility
end

# Each entry in UnicodeData.txt
# (some info is missing but we don't use it yet)
record Entry,
  codepoint : Int32,
  name : String,
  general_category : String,
  decomposition_type : DecompositionType,
  decomposition_mapping : Array(Int32)?,
  upcase : Int32?,
  downcase : Int32?,
  casefold : Int32?

record SpecialCase,
  codepoint : Int32,
  value : Array(Int32)

record CaseRange, low : Int32, high : Int32, delta : Int32
record AlternateRange, low : Int32, high : Int32
record Stride, low : Int32, high : Int32, stride : Int32
record CanonicalCombiningClassRange, low : Int32, high : Int32, ccc : UInt8
record QuickCheckRange, low : Int32, high : Int32, result : Unicode::QuickCheckResult

def case_ranges(entries, &block)
  ranges = [] of CaseRange
  first_codepoint = nil
  last_codepoint = nil
  first_match = nil
  last_match = nil
  entries.each do |entry|
    codepoint = entry.codepoint
    match = yield entry
    if match
      if last_codepoint == codepoint - 1 && last_match == match - 1
        # Continue streak
      else
        if last_codepoint && last_match
          ranges << CaseRange.new(first_codepoint.not_nil!, last_codepoint, first_match.not_nil! - first_codepoint.not_nil!)
        end
        first_codepoint = codepoint
        first_match = match
      end
    else
      if last_codepoint && last_match
        ranges << CaseRange.new(first_codepoint.not_nil!, last_codepoint, first_match.not_nil! - first_codepoint.not_nil!)
      end
    end

    last_codepoint = codepoint
    last_match = match
  end
  ranges
end

def alternate_ranges(ranges)
  alternate = [] of AlternateRange

  first_codepoint = nil
  last_codepoint = nil

  ranges.each do |range|
    codepoint = range.low
    if last_codepoint == codepoint - 2
      # Continue streak
    else
      if first_codepoint
        alternate << new_alternate_range(first_codepoint, last_codepoint)
      end
      first_codepoint = codepoint
    end

    last_codepoint = codepoint
  end

  if first_codepoint
    alternate << new_alternate_range(first_codepoint, last_codepoint)
  end

  alternate
end

def new_alternate_range(first_codepoint, last_codepoint)
  # The last codepoint is the one for the uppercase letter and we
  # need to also consider the next codepoint for the lowercase one.
  AlternateRange.new(first_codepoint, last_codepoint.not_nil! + 1)
end

def strides(entries, targets, &)
  strides = [] of Stride

  entries = entries.select { |entry| targets.includes?(yield entry) }

  first_entry = nil
  last_entry = nil
  stride = nil

  entries.each do |entry|
    if first_entry
      if last_entry
        current_stride = entry.codepoint - last_entry.codepoint
        if current_stride == stride
          # Continue stride
        else
          if first_entry == last_entry
            stride = current_stride
          else
            stride = 1 if first_entry.name.ends_with?("First>") && last_entry.name.ends_with?("Last>")
            strides << Stride.new(first_entry.codepoint, last_entry.codepoint, stride.not_nil!)
            first_entry = entry
            stride = nil
          end
        end
      end
    else
      first_entry = entry
    end

    last_entry = entry
  end

  if first_entry && last_entry
    if stride
      stride = 1 if first_entry.name.ends_with?("First>") && last_entry.name.ends_with?("Last>")
      strides << Stride.new(first_entry.codepoint, last_entry.codepoint, stride)
    else
      strides << Stride.new(first_entry.codepoint, last_entry.codepoint, 1)
    end
  end

  strides
end

entries = [] of Entry
special_cases_downcase = [] of SpecialCase
special_cases_titlecase = [] of SpecialCase
special_cases_upcase = [] of SpecialCase
special_cases_casefold = [] of SpecialCase
casefold_mapping = Hash(Int32, Int32).new
canonical_combining_classes = [] of CanonicalCombiningClassRange
full_composition_exclusions = Set(Int32).new
quick_checks = Unicode::NormalizationForm.values.to_h { |kind| {kind, Array(QuickCheckRange).new} }

url = "#{UCD_ROOT}CaseFolding.txt"
body = HTTP::Client.get(url).body
body.each_line do |line|
  line = line.strip
  next if line.empty?
  next if line.starts_with?('#')

  pieces = line.split(';')
  codepoint = pieces[0].to_i(16)
  status = pieces[1].strip[0]
  casefold = pieces[2].split.map(&.to_i(16))
  next if status != 'C' && status != 'F' # casefold uses full case folding (C and F)
  if casefold.size == 1
    casefold_mapping[codepoint] = casefold[0]
    casefold = nil
  end
  if casefold
    while casefold.size < 3
      casefold << 0
    end
    special_cases_casefold << SpecialCase.new(codepoint, casefold)
  end
end

url = "#{UCD_ROOT}UnicodeData.txt"
body = HTTP::Client.get(url).body
body.each_line do |line|
  line = line.strip
  next if line.empty?

  pieces = line.split(';')
  codepoint = pieces[0].to_i(16)
  name = pieces[1]
  general_category = pieces[2]
  # don't read CanonicalCombiningClass here; the derived properties file has
  # exact ranges
  decomposition = pieces[5]
  if decomposition.starts_with?('<')
    decomposition_mapping = decomposition.partition("> ")[2].split.map(&.to_i(16))
    decomposition_type = DecompositionType::Compatibility
  else
    decomposition_mapping = decomposition.presence.try &.split.map(&.to_i(16))
    decomposition_type = decomposition_mapping.nil? ? DecompositionType::None : DecompositionType::Canonical
  end
  upcase = pieces[12].to_i?(16)
  downcase = pieces[13].to_i?(16)
  titlecase = pieces[14].to_i?(16)
  casefold = casefold_mapping[codepoint]?
  entries << Entry.new(
    codepoint: codepoint,
    name: name,
    general_category: general_category,
    decomposition_type: decomposition_type,
    decomposition_mapping: decomposition_mapping,
    upcase: upcase,
    downcase: downcase,
    casefold: casefold,
  )
  if titlecase && titlecase != upcase
    special_cases_titlecase << SpecialCase.new(codepoint, [titlecase, 0, 0])
  end
end

url = "#{UCD_ROOT}SpecialCasing.txt"
body = HTTP::Client.get(url).body
body.each_line do |line|
  line = line.strip
  next if line.empty?
  break if line.starts_with?("# Conditional Mappings")
  next if line.starts_with?('#')

  pieces = line.split(';')
  codepoint = pieces[0].to_i(16)

  downcase = pieces[1].split.map(&.to_i(16))
  if downcase.size > 1
    while downcase.size < 3
      downcase << 0
    end
    special_cases_downcase << SpecialCase.new(codepoint, downcase)
  end

  upcase = pieces[3].split.map(&.to_i(16))
  if upcase.size > 1
    while upcase.size < 3
      upcase << 0
    end
    special_cases_upcase << SpecialCase.new(codepoint, upcase)
  end

  titlecase = pieces[2].split.map(&.to_i(16))
  if titlecase.size > 1
    while titlecase.size < 3
      titlecase << 0
    end
    special_cases_titlecase << SpecialCase.new(codepoint, titlecase)
  end
end

url = "#{UCD_ROOT}extracted/DerivedCombiningClass.txt"
body = HTTP::Client.get(url).body
body.each_line do |line|
  line = line.strip

  if m = line.match(/^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*(\d+)/)
    ccc = m[3].to_u8
    next if ccc == 0
    low = m[1].to_i(16)
    high = m[2]?.try(&.to_i(16)) || low
    canonical_combining_classes << CanonicalCombiningClassRange.new(low, high, ccc)
  end
end

url = "#{UCD_ROOT}DerivedNormalizationProps.txt"
body = HTTP::Client.get(url).body
body.each_line do |line|
  line = line.strip
  break if line.starts_with?("# Derived Property: Expands_On_NFD")

  if m = line.match(/^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*Full_Composition_Exclusion/)
    low = m[1].to_i(16)
    high = m[2]?.try(&.to_i(16)) || low
    (low..high).each { |codepoint| full_composition_exclusions << codepoint }
  elsif m = line.match(/^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*(NFC|NFD|NFKC|NFKD)_QC\s*;\s*(N|M)/)
    low = m[1].to_i(16)
    high = m[2]?.try(&.to_i(16)) || low
    quick_check = quick_checks[Unicode::NormalizationForm.parse(m[3])]
    result = m[4] == "M" ? Unicode::QuickCheckResult::Maybe : Unicode::QuickCheckResult::No
    quick_check << QuickCheckRange.new(low, high, result)
  end
end

downcase_ranges = case_ranges entries, &.downcase
downcase_one_ranges, downcase_ranges = downcase_ranges.partition { |r| r.delta == 1 }

upcase_ranges = case_ranges entries, &.upcase
upcase_ranges.select! { |r| r.delta != -1 }

alternate_ranges = alternate_ranges(downcase_one_ranges)

special_cases_downcase.sort_by! &.codepoint
special_cases_upcase.sort_by! &.codepoint
special_cases_titlecase.reject! &.in?(special_cases_upcase)
special_cases_titlecase.sort_by! &.codepoint

casefold_ranges = case_ranges entries, &.casefold

all_strides = {} of String => Array(Stride)
categories = %w(Lu Ll Lt Lm Lo Mn Mc Me Nd Nl No Zs Zl Zp Cc Cf Cs Co Cn)

categories.each do |category|
  all_strides[category] = strides entries, category, &.general_category
end

canonical_combining_classes.sort_by! &.low

canonical_decompositions = entries.compact_map do |entry|
  next unless entry.decomposition_type.canonical?
  mapping = entry.decomposition_mapping.not_nil!
  raise "BUG: Mapping longer than 2 codepoints" unless mapping.size <= 2
  {entry.codepoint, mapping[0], mapping[1]? || 0}
end

# Instead of storing the codepoints for each compatibility decomposition as an
# individual `Array`, we store all of them in a single `Array` and refer to its
# subsequences using index and count.
compatibility_decomposition_data = [] of Int32
compatibility_decompositions = entries.compact_map do |entry|
  next unless entry.decomposition_type.compatibility?
  mapping = entry.decomposition_mapping.not_nil!

  # We try to reuse any existing subsequences in the table that match this
  # entry's decomposition mapping. This reduces the table size by over 40%,
  # mainly due to singleton decompositions. It can be further optimized by
  # solving the shortest common superstring problem.
  index = (0..compatibility_decomposition_data.size - mapping.size).find do |i|
    (0...mapping.size).all? do |j|
      mapping[j] == compatibility_decomposition_data[i + j]
    end
  end
  unless index
    index = compatibility_decomposition_data.size
    compatibility_decomposition_data.concat(mapping)
  end

  {entry.codepoint, index, mapping.size}
end

canonical_compositions = canonical_decompositions.compact_map do |codepoint, first, second|
  next if second == 0 || full_composition_exclusions.includes?(codepoint)
  {(first.to_i64 << 21) | second, codepoint}
end

quick_checks.each_value &.sort_by! &.low

output = ECR.render "#{__DIR__}/unicode_data.ecr"
output = Crystal.format(output)
File.write("#{__DIR__}/../src/unicode/data.cr", output)
