#! /usr/bin/env crystal
#
# This script generates the file src/string/grapheme/properties.cr
# that contains compact representations of the GraphemeBreakProperty.txt and emoji-data.txt
# file from the unicode specification.

require "http/client"
require "ecr"

record RRange, low : Int32, high : Int32, prop : String

UCD_ROOT = "http://www.unicode.org/Public/#{Unicode::VERSION}/ucd/"

def shapeup(arr)
  i = 0
  to_del = Array(Int32).new
  while i < arr.size - 1
    if arr[i].high + 1 == arr[i + 1].low
      low = arr[i].low
      to_del << i
      arr.delete_at(i)
      arr[i] = RRange.new(low, arr[i].high, arr[i].prop)
      i -= 1
    end
    i += 1
  end
  arr
end

def parse_graphemes_data(body)
  result = Hash(String, Array(RRange)).new
  body.each_line do |line|
    next unless line = line.strip.presence
    next if line.starts_with?('#')
    parts = line.split(';')
    next unless parts.size >= 2

    fields = parts.first.strip.split("..")
    f1 = fields.first.to_i(16)
    f2 = fields.size > 1 ? fields[1].to_i(16) : f1

    prop = parts[1].split('#').first.strip.gsub('_', "")

    (result[prop] ||= Array(RRange).new) << RRange.new(f1, f2, prop)
  end
  result.transform_values { |v| shapeup(v) }
end

def parse_emoji(body)
  emoji = Array(RRange).new
  body.each_line do |line|
    next unless line = line.strip.presence
    next if line.starts_with?('#')
    next unless line.includes?("; Extended_Pictographic")

    data = line.split.first.split(';')
    fields = data.first.split("..")
    f1 = fields.first.to_i(16)
    f2 = fields.size > 1 ? fields[1].to_i(16) : f1
    next if f2 < 0xFF
    emoji << RRange.new(f1, f2, "ExtendedPictographic")
  end
  shapeup(emoji)
end

body = HTTP::Client.get("#{UCD_ROOT}auxiliary/GraphemeBreakProperty.txt").body
props = parse_graphemes_data(body)

body = HTTP::Client.get("#{UCD_ROOT}emoji/emoji-data.txt").body
props["ExtendedPictographic"] = parse_emoji(body)

props_data = props.values.flatten.sort! { |a, b| a.low <=> b.low }

path = "#{__DIR__}/../src/string/grapheme/properties.cr"
File.open(path, "w") do |file|
  ECR.embed "#{__DIR__}/grapheme_properties.ecr", file
end

`crystal tool format #{path}`
