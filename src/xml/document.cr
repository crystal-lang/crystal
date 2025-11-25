require "weak_ref"

class XML::Document < XML::Node
  # :nodoc:
  #
  # The constructors allocate a XML::Node for a libxml node once, so we don't
  # finalize a document twice for example.
  #
  # We store the reference into the libxml struct (_private) for documents
  # because a document's XML::Node lives as long as its libxml doc. However we
  # can lose references to subtree XML::Node, so using _private would leave
  # dangling pointers. We thus keep a cache of weak references to all nodes in
  # the document, so we can still collect lost references, and at worst
  # reinstantiate a XML::Node if needed.
  #
  # NOTE: when a XML::Node is moved to another document, the XML::Node and any
  # instantiated descendant XML::Node shall be cleaned from the original
  # document's cache, and must be added to the new document's cache.
  protected getter cache : Hash(LibXML::Node*, WeakRef(Node))

  # :nodoc:
  #
  # Unlinked libxml nodes, and all their descendant nodes, don't appear in the
  # document's tree anymore, and must be manually freed, yet we can't merely
  # free the libxml node in a finalizer, because it would free the whole
  # subtree, while we may still have live XML::Node instances.
  #
  # We keep an explicit list of unlinked libxml nodes. We can't rely on the
  # cache because it uses weak references and the XML::Node could be collected,
  # leaking the libxml node and its subtree.
  #
  # NOTE: the libxml node, along with any descendant shall be removed from the
  # list when relinked into a tree, be it the same document or another.
  protected getter unlinked_nodes : Set(LibXML::Node*)

  # :nodoc:
  def self.new(doc : LibXML::Doc*, errors : Array(Error)? = nil) : Document
    if ptr = doc.value._private
      ptr.as(Document)
    else
      new(doc_: doc, errors_: errors)
    end
  end

  # Must never be called directly, use the constructors above.
  private def initialize(*, doc_ : LibXML::Doc*, errors_ : Array(Error)?)
    @node = doc_.as(LibXML::Node*)
    @errors = errors_
    @cache = Hash(LibXML::Node*, WeakRef(Node)).new
    @unlinked_nodes = Set(LibXML::Node*).new
    @document = self
    doc_.value._private = self.as(Void*)
  end

  # :nodoc:
  def finalize
    # free unlinked nodes and their subtrees
    @unlinked_nodes.each do |node|
      if node.value.doc.as(LibXML::Node*) == @node
        LibXML.xmlFreeNode(node)
      else
        # the node has been adopted into another document, don't free!
      end
    end

    # free the doc and its subtree
    LibXML.xmlFreeDoc(@node.as(LibXML::Doc*))
  end

  # Returns the encoding of this node's document.
  def encoding : String?
    if encoding = @node.as(LibXML::Doc*).value.encoding
      String.new(encoding)
    end
  end

  # Returns the version of this node's document.
  def version : String?
    if version = @node.as(LibXML::Doc*).value.version
      String.new(version)
    end
  end

  # :nodoc:
  def document : Document
    self
  end

  # Returns the list of `XML::Error` found when parsing this document.
  # Returns `nil` if no errors were found.
  def errors : Array(XML::Error)?
    @errors unless @errors.try &.empty?
  end
end
