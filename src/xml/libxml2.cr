require "./type"
require "./parser_options"
require "./save_options"

@[Link("xml2")]
lib LibXML
  $xmlIndentTreeOutput : Int32
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
    node_nr : Int32
    node_max : Int32
    node_tab : Node**
  end

  type InputBuffer = Void*
  type XMLTextReader = Void*
  type XMLTextReaderLocator = Void*

  enum ParserSeverity
    VALIDITY_WARNING = 1
    VALIDITY_ERROR = 2
    WARNING = 3
    ERROR = 4
  end

  alias TextReaderErrorFunc = (Void*, UInt8*, ParserSeverity, XMLTextReaderLocator) ->

  fun xmlParserInputBufferCreateStatic(mem : UInt8*, size : Int32, encoding : Int32) : InputBuffer
  fun xmlParserInputBufferCreateIO(ioread : (Void*, UInt8*, Int32) -> Int32, ioclose : Void* -> Int32, ioctx : Void*, enc : Int32) : InputBuffer
  fun xmlNewTextReader(input : InputBuffer, uri : UInt8*) : XMLTextReader

  fun xmlTextReaderRead(reader : XMLTextReader) : Int32
  fun xmlTextReaderNodeType(reader : XMLTextReader) : XML::Type
  fun xmlTextReaderConstName(reader : XMLTextReader) : UInt8*
  fun xmlTextReaderIsEmptyElement(reader : XMLTextReader) : Int32
  fun xmlTextReaderConstValue(reader : XMLTextReader) : UInt8*
  fun xmlTextReaderHasAttributes(reader : XMLTextReader) : Int32
  fun xmlTextReaderAttributeCount(reader : XMLTextReader) : Int32
  fun xmlTextReaderMoveToFirstAttribute(reader : XMLTextReader) : Int32
  fun xmlTextReaderMoveToNextAttribute(reader : XMLTextReader) : Int32

  fun xmlTextReaderSetErrorHandler(reader : XMLTextReader, f : TextReaderErrorFunc) : Void

  fun xmlTextReaderLocatorLineNumber(XMLTextReaderLocator) : Int32

  fun xmlReadMemory(buffer : UInt8*, size : Int32, url : UInt8*, encoding : UInt8*, options : XML::ParserOptions) : DocPtr

  alias InputReadCallback = (Void*, UInt8*, Int32) -> Int32
  alias InputCloseCallback = (Void*) -> Int32

  fun xmlReadIO(ioread : InputReadCallback, ioclose : InputCloseCallback, ioctx : Void*, url : UInt8*, encoding : UInt8*, options : XML::ParserOptions) : DocPtr

  fun xmlDocGetRootElement(doc : DocPtr) : Node*
  fun xmlXPathNodeSetCreate(node : Node*) : NodeSet*
  fun xmlXPathNodeSetAddUnique(cur : NodeSet*, val : Node*) : Int32
  fun xmlNodeGetContent(node : Node*) : UInt8*

  fun xmlGcMemSetup(free_func : Void* ->,
                    malloc_func : LibC::SizeT -> Void*,
                    malloc_atomic_func : LibC::SizeT -> Void*,
                    realloc_func : Void*, LibC::SizeT -> Void*,
                    strdup_func : UInt8* -> UInt8*) : Int32

  alias OutputWriteCallback = (Void*, UInt8*, Int32) -> Int32
  alias OutputCloseCallback = (Void*) -> Int32

  type SaveCtxPtr = Void*

  fun xmlSaveToIO(iowrite : OutputWriteCallback, ioclose : OutputCloseCallback, ioctx : Void*, encoding : UInt8*, options : XML::SaveOptions) : SaveCtxPtr
  fun xmlSaveTree(ctx : SaveCtxPtr, node : Node*) : Int64
  fun xmlSaveClose(ctx : SaveCtxPtr) : Int32

  enum ErrorLevel
    NONE = 0
    WARNING = 1
    ERROR = 2
    FATAL = 3
  end

  struct Error
    domain : Int32
    code : Int32
    message : UInt8*
    level : ErrorLevel
    file : UInt8*
    line : Int32
    str1 : UInt8*
    str2 : UInt8*
    str3 : UInt8*
    int1 : Int32
    int2 : Int32
    ctxt : Void*
    node : Void*
  end

  fun xmlGetLastError() : Error*

  struct XPathContext
    doc : DocPtr
    node : Node*
    nb_variables_unused : Int32
    max_variables_unused : Int32
    varHash : Void*
    nb_types : Int32
    max_types : Int32
    types : Void*
    nb_funcs_unused : Int32
    max_funcs_unused : Int32
    funcHash : Void*
    nb_axis : Int32
    max_axis : Int32
    axis : Void*
    namespaces : Void*
    nsNr : Int32
    user : Void*
    context_size : Int32
    proximity_position : Int32
    xptr : Int32
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
    tmpNsNr : Int32
    userData : Void*
    error : Void*
    lastError : Error
    debugNode : Node*
    dictPtr : Void*
    flags : Int32
    cache : Void*
  end

  enum XPathObjectType
    UNDEFINED = 0
    NODESET = 1
    BOOLEAN = 2
    NUMBER = 3
    STRING = 4
    POINT = 5
    RANGE = 6
    LOCATIONSET = 7
    USERS = 8
    XSLT_TREE = 9
  end

  struct XPathObject
    type : XPathObjectType
    nodesetval : NodeSet*
    boolval : Int32
    floatval : Float64
    stringval : UInt8*
    user : Void*
    index : Int32
    user2 : Void*
    index2 : Int32
  end

  fun xmlXPathInit
  fun xmlXPathNewContext(doc : DocPtr) : XPathContext*

  @[Raises]
  fun xmlXPathEvalExpression(str : UInt8*, ctx : XPathContext*) : XPathObject*

  fun xmlXPathRegisterNs(ctx : XPathContext*, prefix : UInt8*, uri : UInt8*) : Int32
  fun xmlXPathRegisterVariable(ctx : XPathContext*, name : UInt8*, value : XPathObject*) : Int32
  fun xmlXPathNewCString(val : UInt8*) : XPathObject*
  fun xmlXPathNewFloat(val : Float64) : XPathObject*
  fun xmlXPathNewBoolean(val : Int32) : XPathObject*

  alias StructuredErrorFunc = (Void*, Error*) ->
  alias GenericErrorFunc = (Void*, UInt8*) ->

  fun xmlSetStructuredErrorFunc(ctx : Void*, f : StructuredErrorFunc)
  fun xmlSetGenericErrorFunc(ctx : Void*, f : GenericErrorFunc)

  fun xmlGetNsList(doc : DocPtr, node : Node*) : NS**
end

LibXML.xmlGcMemSetup(
  ->GC.free,
  ->(size) { GC.malloc(size.to_u32) },
  ->(size) { GC.malloc(size.to_u32) },
  ->(mem, size) { GC.realloc(mem, size.to_u32) },
  ->(str) {
    len = LibC.strlen(str)
    copy = Pointer(UInt8).malloc(len)
    copy.copy_from(str, len)
    copy
  }
)


