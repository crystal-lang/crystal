class Crystal::Doc::Generator
  def initialize(@program, @included_dirs, @dir = "./doc")
    @base_dir = `pwd`.chomp
    compute_repository
  end

  def run
    `rm -rf #{@dir}`
    Dir.mkdir_p @dir

    types = collect_subtypes(@program)

    program_type = type(@program)
    if program_type.class_methods.any? { |method| must_include? method }
      types.insert 0, program_type
    end

    generate_docs types
  end

  def generate_docs(types)
    copy_files
    generate_list types
    generate_types_docs types, @dir
  end

  def copy_files
    Dir.mkdir_p "#{@dir}/css"
    cp "index.html"
    cp "main.html"
    cp "css/style.css"
  end

  def cp(filename)
    `cp #{__DIR__}/html/#{filename} #{@dir}/#{filename}`
  end

  def generate_list(types)
    write_template "#{@dir}/list.html", ListTemplate.new(types)
  end

  def generate_types_docs(types, dir)
    types.each do |type|
      if type.program?
        filename = "#{dir}/toplevel.html"
      else
        filename = "#{dir}/#{type.name}.html"
      end

      write_template filename, TypeTemplate.new(type)

      next if type.program?

      subtypes = type.types
      if subtypes && !subtypes.empty?
        dirname = "#{dir}/#{type.name}"
        Dir.mkdir_p dirname
        generate_types_docs subtypes, dirname
      end
    end
  end

  def write_template(filename, template)
    File.open(filename, "w") do |file|
      io = BufferedIO.new(file)
      template.to_s io
      io.flush
    end
  end

  def must_include?(type : Type)
    must_include? type.type
  end

  def must_include?(type : Crystal::Type)
    type.locations.any? do |type_location|
      must_include? type_location
    end
  end

  def must_include?(method : Method)
    must_include? method.def
  end

  def must_include?(a_def : Crystal::Def)
    must_include? a_def.location
  end

  def must_include?(a_macro : Macro)
    must_include? a_macro.macro
  end

  def must_include?(a_macro : Crystal::Macro)
    must_include? a_macro.location
  end

  def must_include?(location : Crystal::Location)
    case filename = location.filename
    when String
      @included_dirs.any? { |included_dir| filename.starts_with? included_dir }
    when VirtualFile
      must_include? filename.expanded_location
    else
      false
    end
  end

  def must_include?(nil : Nil)
    false
  end

  def type(type)
    Type.new(self, type)
  end

  def method(type, method, class_method)
    Method.new(self, type, method, class_method)
  end

  def macro(type, a_macro)
    Macro.new(self, type, a_macro)
  end

  def collect_subtypes(parent)
    types = [] of Type

    parent.types.each_value do |type|
      case type
      when Const, LibType
        next
      end

      types << type(type) if must_include? type
    end

    types.sort_by! &.name.downcase
  end

  def collect_constants(parent)
    types = [] of Constant

    parent.types.each_value do |type|
      if type.is_a?(Const)
        types << Constant.new(self, type)
      end
    end

    types.sort_by! &.name.downcase
  end

  def summary(obj : Type | Method | Macro)
    doc = obj.doc
    return nil unless doc

    summary doc
  end

  def summary(str : String)
    first_line = fetch_doc_lines(str).lines.first?
    return nil unless first_line

    dot_index = first_line =~ /\.($|\s)/
    return first_line unless dot_index

    first_line[0 .. dot_index]
  end

  def doc(str : String)
    Markdown.to_html(str)
  end

  def doc(obj)
    doc = obj.doc
    return nil unless doc

    doc doc
  end

  def fetch_doc_lines(doc)
    doc.gsub /\n+/ do |match|
      if match.length == 1
        " "
      else
        "\n"
      end
    end
  end

  def compute_repository
    remotes = `git remote -v`
    return unless  $?.success?

    remotes.lines.each do |line|
      next unless line =~ /github\.com(?:\:|\/)(\w+)\/(\w+)/

      user, repo = $1, $2
      rev = `git rev-parse HEAD`.chomp

      @repository = "https://github.com/#{user}/#{repo}/blob/#{rev}"
      break
    end
  end

  def source_link(node)
    repository = @repository
    return unless repository

    location = node.location
    return unless location

    filename = location.filename
    if filename.is_a?(VirtualFile)
      location = filename.expanded_location
    end

    return unless location

    filename = location.filename
    return unless filename.is_a?(String)

    return unless filename.starts_with? @base_dir

    "#{repository}#{filename[@base_dir.length .. -1]}#L#{location.line_number}"
  end
end
