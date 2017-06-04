# This script generates the file src/unicode/data.cr
# that contains compact representations of the UnicodeData.txt
# file from the unicode specification.

require "http/client"
require "ecr"
require "../src/compiler/crystal/formatter"

UCD_ROOT = "http://www.unicode.org/Public/9.0.0/ucd/"

# Each entry in UnicodeData.txt
# (some info is missing but we don't use it yet)
record Entry,
  codepoint : Int32,
  name : String,
  general_category : String,
  upcase : Int32?,
  downcase : Int32?,
  casefold : Int32?

record SpecialCase,
  codepoint : Int32,
  value : Array(Int32)

record CaseRange, low : Int32, high : Int32, delta : Int32
record AlternateRange, low : Int32, high : Int32
record Stride, low : Int32, high : Int32, stride : Int32

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
        alternate << AlternateRange.new(first_codepoint, last_codepoint.not_nil!)
      end
      first_codepoint = codepoint
    end

    last_codepoint = codepoint
  end

  if first_codepoint
    alternate << AlternateRange.new(first_codepoint, last_codepoint.not_nil!)
  end

  alternate
end

def strides(entries, targets)
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
special_cases_upcase = [] of SpecialCase
special_cases_casefold = [] of SpecialCase
casefold_mapping = Hash(Int32, Int32).new

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
    while casefold.size < 4
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
  upcase = pieces[12].to_i?(16)
  downcase = pieces[13].to_i?(16)
  casefold = casefold_mapping[codepoint]?
  entries << Entry.new(codepoint, name, general_category, upcase, downcase, casefold)
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
  upcase = pieces[3].split.map(&.to_i(16))
  downcase = nil if downcase.size == 1
  upcase = nil if upcase.size == 1
  if downcase
    while downcase.size < 3
      downcase << 0
    end
    special_cases_downcase << SpecialCase.new(codepoint, downcase)
  end
  if upcase
    while upcase.size < 3
      upcase << 0
    end
    special_cases_upcase << SpecialCase.new(codepoint, upcase)
  end
end

downcase_ranges = case_ranges entries, &.downcase
downcase_one_ranges, downcase_ranges = downcase_ranges.partition { |r| r.delta == 1 }

upcase_ranges = case_ranges entries, &.upcase
upcase_ranges.select! { |r| r.delta != -1 }

alternate_ranges = alternate_ranges(downcase_one_ranges)

casefold_ranges = case_ranges entries, &.casefold

all_strides = {} of String => Array(Stride)
categories = %w(Lu Ll Lt Mn Mc Me Nd Nl No Zs Zl Zp Cc Cf Cs Co Cn)

categories.each do |category|
  all_strides[category] = strides entries, category, &.general_category
end

output = String.build do |str|
  ECR.embed "#{__DIR__}/unicode_data.ecr", str
end
output = Crystal.format(output)
File.write("#{__DIR__}/../src/unicode/data.cr", output)
