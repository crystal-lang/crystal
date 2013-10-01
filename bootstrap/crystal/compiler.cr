require "option_parser"

module Crystal
  class Compiler
    include Crystal

    def initialize
      @options = OptionParser.parse! do |opts|
        opts.banner = "Usage: crystal [switches] [--] [programfile] [arguments]"
        opts.on("-ll", "Dump ll to standard output") do
          @dump_ll = true
        end
        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit 1
        end
      end
    end

    def compile
      if ARGV.length == 0
        puts @options
        exit 1
      end

      filename = ARGV[0]
      unless File.exists?(filename)
        puts "File #{filename} does not exist"
        exit 1
      end

      bitcode_filename = "foo.bc"
      output_filename = "foo"

      source = File.read filename

      begin
        program = Program.new
        parser = Parser.new(source)
        parser.filename = filename
        nodes = parser.parse
        nodes = program.normalize nodes
        nodes = program.infer_type nodes
        llvm_mod = program.build nodes

        llvm_mod.dump if @dump_ll

        llvm_mod.write_bitcode bitcode_filename

        system "llc-3.3 #{bitcode_filename} -o - | clang -x assembler -o #{output_filename} -"
      rescue ex : Crystal::Exception
        puts ex
      end
    end
  end
end
