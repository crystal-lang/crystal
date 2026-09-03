require "../src/reply"

class MyReader < Reply::Reader
end

reader = MyReader.new

reader.read_loop do |expression|
  # Eval expression here
  puts " => #{expression}"
end
