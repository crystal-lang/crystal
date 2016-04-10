require "./renderer"

class Markdown::HTMLRenderer
  include Renderer

  def initialize(@io : IO)
  end

  def begin_paragraph
    @io << "<p>"
  end

  def end_paragraph
    @io << "</p>"
  end

  def begin_italic
    @io << "<em>"
  end

  def end_italic
    @io << "</em>"
  end

  def begin_bold
    @io << "<strong>"
  end

  def end_bold
    @io << "</strong>"
  end

  def begin_header(level)
    @io << "<h"
    @io << level
    @io << '>'
  end

  def end_header(level)
    @io << "</h"
    @io << level
    @io << '>'
  end

  def begin_inline_code
    @io << "<code>"
  end

  def end_inline_code
    @io << "</code>"
  end

  def begin_code(language)
    if language.nil?
      @io << "<pre><code>"
    else
      @io << "<pre><code class='language-#{language}'>"
    end
  end

  def end_code
    @io << "</code></pre>"
  end

  def begin_quote
    @io << "<blockquote>"
  end

  def end_quote
    @io << "</blockquote>"
  end

  def begin_unordered_list
    @io << "<ul>"
  end

  def end_unordered_list
    @io << "</ul>"
  end

  def begin_ordered_list
    @io << "<ol>"
  end

  def end_ordered_list
    @io << "</ol>"
  end

  def begin_list_item
    @io << "<li>"
  end

  def end_list_item
    @io << "</li>"
  end

  def begin_link(url)
    @io << %(<a href=")
    @io << url
    @io << %(">)
  end

  def end_link
    @io << "</a>"
  end

  def image(url, alt)
    @io << %(<img src=")
    @io << url
    @io << %(" alt=")
    @io << alt
    @io << %("/>)
  end

  def text(text)
    @io << text.gsub('<', "&lt;")
  end

  def horizontal_rule
    @io << "<hr/>"
  end
end
