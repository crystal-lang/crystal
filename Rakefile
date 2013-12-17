# Rake tasks to parse haml layouts, includes and index files and sass files for jekyll
# Assumes that the haml files are in (_layouts|_includes)/_haml
# and the less files are in css/_less

namespace :haml do
  require 'haml'

  def convert file, destination
    base_name = File.basename(file, '.haml') + '.html'
    html = Haml::Engine.new(File.read(file)).render
    File.open(File.join(destination, base_name), 'w') { |f| f.write html }
  end

  desc 'Parse haml layout files'
  task :layouts do
    Dir.glob('_layouts/_haml/*.haml') do |path|
      convert path, '_layouts'
    end

    puts 'Parsed haml layout files'
  end

  desc 'Parse haml include files'
  task :includes do
    Dir.glob('_includes/_haml/*.haml') do |path|
      convert path, '_includes'
    end

    puts 'Parsed haml include files'
  end

  desc 'Parse haml index files'
  task :indexes do
    Dir.glob('**/index.haml') do |path|
      convert path, File.dirname(path)
    end

    puts 'Parsed haml index files'
  end
end

desc 'Parse less files'
task :less do
  require 'less'

  parser = Less::Parser.new filename: "stylesheet.css", paths: "stylesheets/_sass"
  css = parser.parse(File.read("stylesheets/_sass/stylesheet.less")).to_css
  File.open('stylesheets/stylesheet.css', 'w') { |f| f.write css }

  puts 'Parsed main.sass'
end

desc 'Build docs'
task :docs do
  Dir.chdir "./docs"
  system "asciidoc -b html5 -a icons -a toc2 -a iconsdir=`brew --prefix asciidoc`/etc/asciidoc/images/icons -a data-uri -a theme=flask -a source-highlighter=pygments -o ../docs.html index.asciidoc"
end

desc 'Parse all haml items'
task haml: ['haml:layouts', 'haml:includes', 'haml:indexes']

desc 'Build all haml and sass files for deployment'
task build: [:haml, :less, :docs]
