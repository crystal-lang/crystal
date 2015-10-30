require "./type"
require "./parser_options"
require "./html_parser_options"
require "./save_options"

@[Link("xml2")]
lib LibXML
  alias Int = LibC::Int

  $xmlIndentTreeOutput : Int
  $xmlTreeIndentString : UInt8*

  type DocPtr = Void*

  struct NS
    next : NS*
    type : XML::Type
    href : UInt8*
    prefix : UInt8*
    _private : Void*
    context : DocPtr
  end

  struct NodeCommon
    _private : Void*
    type : XML::Type
    name : UInt8*
    children : Node*
    last : Node*
    parent : Node*
    next : Node*
    prev : Node*
    doc : DocPtr
  end

  struct Attr
    include NodeCommon
    ns : NS*
    atype : XML::AttributeType
    psvi : Void*
  end

  struct Node
    include NodeCommon
    ns : NS*
    content : UInt8*
    properties : Attr*
    ns_def : NS*
    psvi : Void*
    line : UInt16
    extra : UInt16
  end

  struct NodeSet
    node_nr : Int
    node_max : Int
    node_tab : Node**
  end

  type InputBuffer = Void*
  type XMLTextReader = Void*
  type XMLTextReaderLocator = Void*

  enum ParserSeverity
    VALIDITY_WARNING = 1
    VALIDITY_ERROR   = 2
    WARNING          = 3
    ERROR            = 4
  end

  alias TextReaderErrorFunc = (Void*, UInt8*, ParserSeverity, XMLTextReaderLocator) ->

  fun xmlParserInputBufferCreateStatic(mem : UInt8*, size : Int, encoding : Int) : InputBuffer
  fun xmlParserInputBufferCreateIO(ioread : (Void*, UInt8*, Int) -> Int, ioclose : Void* -> Int, ioctx : Void*, enc : Int) : InputBuffer
  fun xmlNewTextReader(input : InputBuffer, uri : UInt8*) : XMLTextReader

  fun xmlTextReaderRead(reader : XMLTextReader) : Int
  fun xmlTextReaderNodeType(reader : XMLTextReader) : XML::Type
  fun xmlTextReaderConstName(reader : XMLTextReader) : UInt8*
  fun xmlTextReaderIsEmptyElement(reader : XMLTextReader) : Int
  fun xmlTextReaderConstValue(reader : XMLTextReader) : UInt8*
  fun xmlTextReaderHasAttributes(reader : XMLTextReader) : Int
  fun xmlTextReaderAttributeCount(reader : XMLTextReader) : Int
  fun xmlTextReaderMoveToFirstAttribute(reader : XMLTextReader) : Int
  fun xmlTextReaderMoveToNextAttribute(reader : XMLTextReader) : Int

  fun xmlTextReaderSetErrorHandler(reader : XMLTextReader, f : TextReaderErrorFunc) : Void

  fun xmlTextReaderLocatorLineNumber(XMLTextReaderLocator) : Int

  fun xmlReadMemory(buffer : UInt8*, size : Int, url : UInt8*, encoding : UInt8*, options : XML::ParserOptions) : DocPtr
  fun htmlReadMemory(buffer : UInt8*, size : Int, url : UInt8*, encoding : UInt8*, options : XML::HTMLParserOptions) : DocPtr

  alias InputReadCallback = (Void*, UInt8*, Int) -> Int
  alias InputCloseCallback = (Void*) -> Int

  fun xmlReadIO(ioread : InputReadCallback, ioclose : InputCloseCallback, ioctx : Void*, url : UInt8*, encoding : UInt8*, options : XML::ParserOptions) : DocPtr
  fun htmlReadIO(ioread : InputReadCallback, ioclose : InputCloseCallback, ioctx : Void*, url : UInt8*, encoding : UInt8*, options : XML::HTMLParserOptions) : DocPtr

  fun xmlDocGetRootElement(doc : DocPtr) : Node*
  fun xmlXPathNodeSetCreate(node : Node*) : NodeSet*
  fun xmlXPathNodeSetAddUnique(cur : NodeSet*, val : Node*) : Int
  fun xmlNodeGetContent(node : Node*) : UInt8*
  fun xmlNodeSetContent(node : Node*, content : UInt8*)
  fun xmlNodeSetName(node : Node*, name : UInt8*)

  fun xmlGcMemSetup(free_func : Void* ->,
                    malloc_func : LibC::SizeT -> Void*,
                    malloc_atomic_func : LibC::SizeT -> Void*,
                    realloc_func : Void*, LibC::SizeT -> Void*,
                    strdup_func : UInt8* -> UInt8*) : Int

  alias OutputWriteCallback = (Void*, UInt8*, Int) -> Int
  alias OutputCloseCallback = (Void*) -> Int

  type SaveCtxPtr = Void*

  fun xmlSaveToIO(iowrite : OutputWriteCallback, ioclose : OutputCloseCallback, ioctx : Void*, encoding : UInt8*, options : XML::SaveOptions) : SaveCtxPtr
  fun xmlSaveTree(ctx : SaveCtxPtr, node : Node*) : LibC::Long
  fun xmlSaveClose(ctx : SaveCtxPtr) : Int

  enum ErrorLevel
    NONE    = 0
    WARNING = 1
    ERROR   = 2
    FATAL   = 3
  end

  struct Error
    domain : Int
    code : Int
    message : UInt8*
    level : ErrorLevel
    file : UInt8*
    line : Int
    str1 : UInt8*
    str2 : UInt8*
    str3 : UInt8*
    int1 : Int
    int2 : Int
    ctxt : Void*
    node : Void*
  end

  fun xmlGetLastError : Error*

  struct XPathContext
    doc : DocPtr
    node : Node*
    nb_variables_unused : Int
    max_variables_unused : Int
    varHash : Void*
    nb_types : Int
    max_types : Int
    types : Void*
    nb_funcs_unused : Int
    max_funcs_unused : Int
    funcHash : Void*
    nb_axis : Int
    max_axis : Int
    axis : Void*
    namespaces : Void*
    nsNr : Int
    user : Void*
    context_size : Int
    proximity_position : Int
    xptr : Int
    here : Node*
    origin : Node*
    nsHash : Void*
    varLookupFunc : Void*
    varLookupData : Void*
    extra : Void*
    function : UInt8*
    functionURI : UInt8*
    funcLookupFunc : Void*
    funcLookupData : Void*
    tmpNsList : Void*
    tmpNsNr : Int
    userData : Void*
    error : Void*
    lastError : Error
    debugNode : Node*
    dictPtr : Void*
    flags : Int
    cache : Void*
  end

  enum XPathObjectType
    UNDEFINED   = 0
    NODESET     = 1
    BOOLEAN     = 2
    NUMBER      = 3
    STRING      = 4
    POINT       = 5
    RANGE       = 6
    LOCATIONSET = 7
    USERS       = 8
    XSLT_TREE   = 9
  end

  struct XPathObject
    type : XPathObjectType
    nodesetval : NodeSet*
    boolval : Int
    floatval : Float64
    stringval : UInt8*
    user : Void*
    index : Int
    user2 : Void*
    index2 : Int
  end

  fun xmlXPathInit
  fun xmlXPathNewContext(doc : DocPtr) : XPathContext*

  @[Raises]
  fun xmlXPathEvalExpression(str : UInt8*, ctx : XPathContext*) : XPathObject*

  fun xmlXPathRegisterNs(ctx : XPathContext*, prefix : UInt8*, uri : UInt8*) : Int
  fun xmlXPathRegisterVariable(ctx : XPathContext*, name : UInt8*, value : XPathObject*) : Int
  fun xmlXPathNewCString(val : UInt8*) : XPathObject*
  fun xmlXPathNewFloat(val : Float64) : XPathObject*
  fun xmlXPathNewBoolean(val : Int) : XPathObject*

  alias StructuredErrorFunc = (Void*, Error*) ->
  alias GenericErrorFunc = (Void*, UInt8*) ->

  fun xmlSetStructuredErrorFunc(ctx : Void*, f : StructuredErrorFunc)
  fun xmlSetGenericErrorFunc(ctx : Void*, f : GenericErrorFunc)

  fun xmlGetNsList(doc : DocPtr, node : Node*) : NS**
end

LibXML.xmlGcMemSetup(
  ->GC.free,
  ->GC.malloc(LibC::SizeT),
  ->GC.malloc(LibC::SizeT),
  ->GC.realloc(Void*, LibC::SizeT),
  ->(str) {
    len = LibC.strlen(str)
    copy = Pointer(UInt8).malloc(len)
    copy.copy_from(str, len)
    copy
  }
)
