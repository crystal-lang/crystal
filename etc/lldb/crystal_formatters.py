import lldb

_type_id_cache = {}

class CrystalArraySyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.buffer = None
        self.size = 0

    def update(self):
        if self.valobj.type.is_pointer:
            self.valobj = self.valobj.Dereference()
        self.size = int(self.valobj.child[0].value)
        self.type = self.valobj.type
        self.buffer = self.valobj.child[3]

    def num_children(self):
        size = 0 if self.size is None else self.size
        return size

    def get_child_index(self, name):
        try:
            return int(name.lstrip('[').rstrip(']'))
        except:
            return -1

    def get_child_at_index(self,index):
        if index >= self.size:
            return None
        try:
            elementType = self.buffer.type.GetPointeeType()
            offset = elementType.size * index
            return self.buffer.CreateChildAtOffset('[' + str(index) + ']', offset, elementType)
        except Exception as e:
            print('Got exception %s' % (str(e)))
            return None

def findType(name, module):
    cachedTypes = module.GetTypes()
    for idx in range(cachedTypes.GetSize()):
        type = cachedTypes.GetTypeAtIndex(idx)
        if type.name == name:
            return type
    return None


def CrystalString_SummaryProvider(value, dict):
    error = lldb.SBError()
    if value.TypeIsPointerType():
        value = value.Dereference()
    process = value.GetTarget().GetProcess()
    byteSize = int(value.child[0].value)
    len = int(value.child[1].value)
    len = byteSize or len
    strAddr = value.child[2].load_addr
    val = process.ReadCStringFromMemory(strAddr, len + 1, error)
    return '"%s"' % val


def CrystalUnion_UsableSummary(summary):
    return summary is not None and summary != 'None'


def CrystalUnion_ValueSummary(value, depth=0):
    summary = value.GetSummary()
    if CrystalUnion_UsableSummary(summary):
        return summary

    if value.TypeIsPointerType():
        if value.GetValueAsUnsigned(0) == 0:
            return '0x0'

        dereferenced = value.Dereference()
        summary = dereferenced.GetSummary()
        if CrystalUnion_UsableSummary(summary):
            return summary

        if depth <= 1:
            fields = CrystalUnion_FieldSummary(dereferenced, depth + 1)
            if fields is not None:
                return fields

        raw = value.GetValue()
        if raw is not None:
            return raw

        return value.GetTypeName()

    raw = value.GetValue()
    if raw is not None:
        return raw

    fields = CrystalUnion_FieldSummary(value, depth)
    if fields is not None:
        return fields

    return value.GetTypeName()


def CrystalUnion_FieldSummary(value, depth):
    if depth > 1:
        return None

    fields = []
    for index in range(value.GetNumChildren()):
        child = value.GetChildAtIndex(index)
        name = child.GetName()
        if name is None:
            name = ''
        elif name.startswith('@'):
            name = name[1:]
        fields.append('%s = %s' % (name, CrystalUnion_ValueSummary(child, depth + 1)))

    if not fields:
        return None

    return '(%s)' % ', '.join(fields)


def CrystalUnion_TypeIdForName(target, name):
    cache_key = (target.GetExecutable().fullpath, name)
    if cache_key in _type_id_cache:
        return _type_id_cache[cache_key]

    symbol_name = name + ':type_id'
    process = target.GetProcess()
    error = lldb.SBError()

    for module in target.module_iter():
        symbols = module.FindSymbols(symbol_name, lldb.eSymbolTypeAny)
        if symbols.GetSize() == 0:
            continue

        symbol = symbols.GetContextAtIndex(0).GetSymbol()
        load_addr = symbol.GetStartAddress().GetLoadAddress(target)
        if load_addr == lldb.LLDB_INVALID_ADDRESS:
            continue

        type_id = process.ReadUnsignedFromMemory(load_addr, 4, error)
        if error.Success():
            _type_id_cache[cache_key] = type_id
            return type_id

    _type_id_cache[cache_key] = None
    return None


def CrystalUnion_ReadTypeIdFromAddress(target, address):
    if address == 0:
        return None

    error = lldb.SBError()
    type_id = target.GetProcess().ReadUnsignedFromMemory(address, 4, error)
    if error.Success():
        return type_id

    return None


def CrystalUnion_TypeNamesFromTypeName(type_name):
    if type_name is None:
        return []

    type_name = type_name.strip()
    while type_name.endswith('*'):
        type_name = type_name[:-1].strip()

    if not type_name.startswith('(') or not type_name.endswith(')'):
        return []

    return [name.strip() for name in type_name[1:-1].split(' | ')]


def CrystalUnion_ActiveReferenceName(target, type_names, address):
    active_type_id = CrystalUnion_ReadTypeIdFromAddress(target, address)
    if active_type_id is None:
        return None

    for name in type_names:
        if name == 'Nil':
            continue
        if CrystalUnion_TypeIdForName(target, name) == active_type_id:
            return name

    return None


def CrystalUnion_ActiveChild(value):
    if value.TypeIsPointerType():
        address = value.GetValueAsUnsigned(0)
        if address == 0:
            return 'Nil', None

        dereferenced = value.Dereference()
        if (dereferenced.GetChildMemberWithName('type_id').IsValid() and
                dereferenced.GetChildMemberWithName('union').IsValid()):
            value = dereferenced
        else:
            name = CrystalUnion_ActiveReferenceName(
                value.GetTarget(),
                CrystalUnion_TypeNamesFromTypeName(value.GetTypeName()),
                address)
            if name is not None:
                return name, dereferenced
            value = dereferenced

    type_id_child = value.GetChildMemberWithName('type_id')
    union_child = value.GetChildMemberWithName('union')
    target = value.GetTarget()

    if type_id_child.IsValid() and union_child.IsValid():
        active_type_id = type_id_child.GetValueAsUnsigned()

        if CrystalUnion_TypeIdForName(target, 'Nil') == active_type_id:
            return 'Nil', None

        for index in range(union_child.GetNumChildren()):
            child = union_child.GetChildAtIndex(index)
            name = child.GetName()
            if name and CrystalUnion_TypeIdForName(target, name) == active_type_id:
                return name, child

        return None, None

    found_reference_union_child = False
    found_non_null_reference_union_child = False
    for index in range(value.GetNumChildren()):
        child = value.GetChildAtIndex(index)
        if not child.TypeIsPointerType():
            continue

        name = child.GetName()
        expected_type_id = CrystalUnion_TypeIdForName(target, name) if name else None
        if expected_type_id is None:
            continue

        found_reference_union_child = True
        address = child.GetValueAsUnsigned(0)
        if address == 0:
            continue

        found_non_null_reference_union_child = True
        active_type_id = CrystalUnion_ReadTypeIdFromAddress(target, address)
        if active_type_id == expected_type_id:
            return name, child

    if found_reference_union_child and not found_non_null_reference_union_child:
        return 'Nil', None

    return None, None


def CrystalUnion_SummaryProvider(value, dict):
    try:
        name, child = CrystalUnion_ActiveChild(value)
        if name is None:
            return None
        if child is None:
            return name
        return '%s = %s' % (name, CrystalUnion_ValueSummary(child))
    except Exception:
        return None


def __lldb_init_module(debugger, dict):
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalArraySyntheticProvider -x "^Array\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalUnion_SummaryProvider -x "^\(.+ \| .+\)(\s*\**)?$" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalString_SummaryProvider -x "^(String|\(String \| Nil\))(\s*\**)?$" -w Crystal')
    debugger.HandleCommand(r'type category enable Crystal')
