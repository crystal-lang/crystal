module Crystal
  extend self

  DUMP_LLVM = ENV['DUMP'] == '1'
  LOG = ENV['LOG'] == '1'
  CACHE = ENV['CACHE'] != '0'
end

require "levenshtein"
Dir["#{File.expand_path('../',  __FILE__)}/**/*.rb"].sort.each do |filename|
  require filename
end
