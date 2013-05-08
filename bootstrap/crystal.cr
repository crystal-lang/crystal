require "crystal/**"

include Crystal

if ARGV.length == 0
  puts "Usage: test2 [file]"
  exit 1
end

filename = ARGV[0]
bitcode_filename = "foo.bc"
output_filename = "foo"

str = File.read filename

parser = Parser.new(str)
parser.filename = filename
nodes = parser.parse
mod = infer_type nodes
# llvm_mod = build nodes, mod
# llvm_mod.write_bitcode bitcode_filename

# system "llc #{bitcode_filename} -o - | clang -x assembler -o #{output_filename} -"
