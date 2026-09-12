require "spec"
require "../src/markd"

def describe_spec(file, smart = false, render = false, gfm = false)
  file = File.join(__DIR__, file)

  specs = extract_spec_tests(file)

  skip_examples = [] of Int32

  if render
    puts "Run [#{file}] examples"
    examples_count = 0
    section_count = 0
    specs.each_with_index do |(section, examples), index|
      section = "#{(index + 1).to_s.rjust(2)}. #{section} (#{examples.size})"
      if skip_examples.includes?(index + 1)
        puts section + " [SKIP]"
        next
      end
      section_count += 1
      examples_count += examples.size
      puts section
    end
    puts "Total #{section_count} describes and #{examples_count} examples"
  end

  specs.each_with_index do |(section, examples), index|
    no = index + 1
    next if skip_examples.includes?(no)
    assert_section(file, section, examples, smart, gfm)
  end
end

def assert_section(file, section, examples, smart, gfm = false)
  describe section do
    examples.each do |index, example|
      assert_example(file, section, index, example, smart, gfm)
    end
  end
end

def assert_example(file, section, index, example, smart, gfm = false)
  markdown = example["markdown"].gsub("→", "\t").chomp
  html = example["html"].gsub("→", "\t")
  line = example["line"].to_i
  tags = example["test_tags"].split(" ")

  options = Markd::Options.new(
    gfm: gfm || tags.includes?("gfm"),
    emoji: tags.includes?("emoji"),
    tagfilter: tags.includes?("tagfilter"),
    autolink: tags.includes?("autolink")
  )
  options.smart = true if smart

  if example["test_tags"].ends_with?("pending")
    pending "- #{index}\n#{show_space(markdown)}", file, line do
      output = Markd.to_html(markdown, options)
      output.should eq(html), file: file, line: line
    end
  else
    it "- #{index}\n#{show_space(markdown)}", file, line do
      output = Markd.to_html(markdown, options)
      next if html == "<IGNORE>\n"

      output.should eq(html), file: file, line: line
    end
  end
end

def extract_spec_tests(file)
  examples = {} of String => Hash(Int32, Hash(String, String))

  current_section = 0
  example_count = 0
  test_start = false
  result_start = false

  begin
    File.open(file) do |input|
      line_number = 0
      test_tags = ""

      while (line = input.read_line)
        line_number += 1
        line = line.gsub(/\r\n?/, "\n")
        break if line.includes?("<!-- END TESTS -->")

        if !test_start && !result_start && (match = line.match(/^\#{1,6}\s+(.*)$/))
          current_section = match[1]
          examples[current_section] = {} of Int32 => Hash(String, String)
          example_count = 0
        else
          if !test_start && !result_start && line =~ /^`{32} example([a-z ])*$/
            test_start = true
            test_tags = line[line.rindex!(' ') + 1..-1]
          elsif test_start && !result_start && line =~ /^\.$/
            test_start = false
            result_start = true
          elsif !test_start && result_start && line =~ /^`{32}/
            result_start = false
            example_count += 1
          elsif test_start && !result_start
            examples[current_section][example_count] ||= {
              "line"      => line_number.to_s,
              "markdown"  => "",
              "html"      => "",
              "test_tags" => (test_tags == "example" ? "" : test_tags),
            } of String => String

            examples[current_section][example_count]["markdown"] += line + "\n"
          elsif !test_start && result_start
            examples[current_section][example_count]["html"] += line + "\n"
          end
        end
      end
    end
  rescue IO::EOFError
    # do nothing
  end

  # Remove empty examples
  examples.keys.each { |k| examples.delete(k) if examples[k].empty? }
  examples
end

def show_space(text)
  text.gsub("\t", "→").gsub(/ /, '␣')
end
