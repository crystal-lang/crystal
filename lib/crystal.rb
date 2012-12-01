module Crystal
  extend self

  DUMP_LLVM = ENV['DUMP'] == '1'
  UNIFY = ENV['UNIFY'] != '0'
  LOG = ENV['LOG'] == '1'
end

Dir["#{File.expand_path('../',  __FILE__)}/**/*.rb"].each do |filename|
  require filename
end
