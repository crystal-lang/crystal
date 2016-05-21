# Ported from http://arthurtw.github.io/2015/01/12/quick-comparison-nim-vs-rust.html

require "option_parser"

def do_work(in_filenames, output_filename, ignore_case)
  if in_filenames.empty?
    in_files = [STDIN]
  else
    in_files = in_filenames.map { |name| File.open(name, "r") }
  end

  if output_filename
    out_file = File.open(output_filename, "w")
  else
    out_file = STDOUT
  end

  counts = Hash(String, Int32).new(0)

  in_files.each do |in_file|
    in_file.each_line do |line|
      line = line.downcase if ignore_case
      line.scan(/\w+/) do |match|
        counts[match[0]] += 1
      end
    end
  end

  entries = counts.to_a.sort_by! &.[0]
  entries.each do |(word, count)|
    out_file.puts "#{count}\t#{word}"
  end
end

output_filename = nil
ignore_case = false

OptionParser.parse! do |opts|
  opts.banner = "Usage: wordcount [OPTIONS] [FILES]"
  opts.on("-o NAME", "set output filename") do |filename|
    output_filename = filename
  end
  opts.on("-i", "--ignore-case", "ignore case") do
    ignore_case = true
  end
  opts.on("-h", "--help", "print this help menu") do
    puts opts
  end
end

in_filenames = ARGV

do_work ARGV, output_filename, ignore_case
