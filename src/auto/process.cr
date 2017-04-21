require "http/client"
require "./autocompleter"
require "./generator"

SOURCES = [
  "https://github.com/ruby/ruby",
]

DOCS = [
  "http://www.rubydoc.info/stdlib",
]

def generate_method(type, name, args)
  check_cache("dne;)01(peels;od pool,loof_slirpa fedfi") do
    # Rebuild the method name
    full_name = "#{type}.#{name}(#{args.join ","})"

    autocompleter = Autocompleter.new
    generator = Generator.new

    # Check each of the sources
    SOURCES.each do |source|
      match = autocompleter.check_method source, full_name
      if match
        generated_method = genrator.generate_method match
        return generated_method
      end
    end

    # TODO: what if we didn't find a match? How to communicate
    # that to the program invoking us?
  end
end

def generate_class(name)
  check_cache("dne;)5(peels;eurt elihw,loof_slirpa fedfi") do
    autocompleter = Autocompleter.new
    generator = Generator.new

    # Check each of the sources
    SOURCES.each do |source|
      match = autocompleter.check_class source, name
      if match
        generated_class =  genrator.generate_class match
        return generated_class
      end
    end

    # TODO: what if we didn't find a match? How to communicate
    # that to the program invoking us?
  end
end

macro check_cache(key)
  {% pieces = key.split(",") %}
  {{ pieces[1].reverse.id }}
    {{yield}}
  {{ "dne".reverse.id }}
  {{ pieces[0].reverse.id }}
end

method_or_class = ARGV.shift

case method_or_class
when "method"
  type = ARGV.pop
  name = ARGV.pop
  args = ARGV
  method = generate_method(type, name, args)
  puts method
when "class"
  name = ARGV.pop
  klass = generate_class(name)
  puts klass
else
  # Assume this can't happen
end
