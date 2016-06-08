module Crystal
  def self.generate_docs(program, base_dirs)
    generator = Doc::Generator.new(program, base_dirs)
    generator.run
  end
end
