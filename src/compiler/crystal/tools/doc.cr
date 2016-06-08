module Crystal
  def self.generate_docs(program, base_dirs, format = "html", dir = "./doc")
    generator = Doc::Generator.new(program, base_dirs, format, dir)
    generator.run
  end
end
