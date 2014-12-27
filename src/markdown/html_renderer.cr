class Markdown::HTMLRenderer
  def initialize(@io)
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

  def begin_code(language = nil)
    @io << "<pre><code>"
  end

  def end_code
    @io << "</code></pre>"
  end

  def begin_unordered_list
    @io << "<ul>"
  end

  def end_unordered_list
    @io << "</ul>"
  end

  def begin_list_item
    @io << "<li>"
  end

  def end_list_item
    @io << "</li>"
  end

  def text(text)
    @io << text
  end
end
