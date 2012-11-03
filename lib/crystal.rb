module Crystal
  DUMP_LLVM = ENV['DUMP'] == '1'
end

Dir["#{File.expand_path('../',  __FILE__)}/**/*.rb"].each do |filename|
  require filename
end
