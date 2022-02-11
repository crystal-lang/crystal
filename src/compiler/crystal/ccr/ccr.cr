require "./lexer"
require "./c_generator"

module Crystal::CCR
  CC = ENV["CC"]? || "cc"

  def self.process(filename : String)
    dir = File.dirname(filename)
    basename = File.basename(filename, ".ccr")

    generated_c_filename = File.join(dir, "#{basename}.generated.c")
    generated_bin_filename = File.join(dir, "#{basename}.generated.bin")
    generated_cr_filename = File.join(dir, "#{basename}.generated.cr")

    generator = CGenerator.new(filename)

    File.write(generated_c_filename, generator.process)

    status = Process.run(CC, [generated_c_filename, "-o", generated_bin_filename], error: :inherit)
    if !status.success?
      raise Crystal::Error.new("Expanding '#{filename}' resulted in an invalid C program: '#{generated_c_filename}'")
    end

    File.open(generated_cr_filename, "w") do |generated_cr_file|
      Process.run(generated_bin_filename, output: generated_cr_file)
    end

    generated_cr_filename
  end
end
