require "./fs"

fs = FS::DirectoryFileSystem.new(ARGV[0])
puts "FS::MemoryFileSystem.new.tap do |fs|"

def embed(indent, ctx, entry : FS::DirectoryEntry)
  child_ctx = fresh_var
  puts "#{"  " * indent}#{ctx}.add_directory \"#{entry.name}\" do |#{child_ctx}|"
    entry.entries do |child_entry|
      embed(indent+1, child_ctx, child_entry)
    end
  puts "#{"  " * indent}end"
  nil
end

def embed(indent, ctx, entry : FS::FileEntry)
  puts "#{"  " * indent}#{ctx}.add_file \"#{entry.name}\", #{entry.read.inspect}"
  nil
end

def embed(indent, ctx, entry)
  embed(indent, ctx, entry) #dispatch, Entry+ is bodering
end

$index = 0
def fresh_var
  $index+=1
  "ctx#{$index}"
end

fs.entries do |entry|
  embed(1, "fs", entry)
end

puts "end"
