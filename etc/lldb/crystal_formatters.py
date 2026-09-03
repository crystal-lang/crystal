import lldb
import os


# Keep the formatter defensive. lldb-dap eagerly expands locals, including
# inactive union fields and values that are technically in scope but backed by
# bogus layout data. In those cases we prefer returning `None` (or exposing raw
# children) over forcing a synthetic summary that can hang the client.
#
# For mixed unions we resolve the active member via Crystal's runtime
# `<TypeName>:type_id` globals instead of hard-coding numeric ids. This keeps
# the formatter aligned with the current program image and allows nil to render
# as `Nil` instead of a zeroed inactive payload field.
def _env_int(name, default):
    try:
        value = int(os.environ.get(name, default))
        if value > 0:
            return value
    except Exception:
        pass
    return default


MAX_SYNTHETIC_CHILDREN = _env_int('CRYSTAL_LLDB_MAX_SYNTHETIC_CHILDREN', 256)
MAX_HASH_SCAN = _env_int('CRYSTAL_LLDB_MAX_HASH_SCAN', 4096)
MAX_REASONABLE_COLLECTION_SIZE = _env_int('CRYSTAL_LLDB_MAX_REASONABLE_COLLECTION_SIZE', 10000000)

TYPE_ID_SYMBOL_CACHE = {}


def _valid_lldb_value(value):
    return value is not None and value.IsValid() and value.GetError().Success()


def _available_lldb_value(value):
    if not _valid_lldb_value(value):
        return False

    try:
        if not value.IsInScope():
            return False
    except Exception:
        pass

    try:
        declaration = value.GetDeclaration()
        frame_line = value.GetFrame().GetLineEntry().GetLine()
        declaration_line = declaration.GetLine()
        if declaration_line != 0 and frame_line != 0 and declaration_line > frame_line:
            return False
    except Exception:
        pass

    return True


def _has_null_pointer(value):
    return value.TypeIsPointerType() and value.GetValueAsUnsigned(0) == 0


def _valid_child(value, index):
    try:
        return _valid_lldb_value(value.GetChildAtIndex(index))
    except Exception:
        return False


def _child_at(value, index):
    if not _valid_child(value, index):
        return None
    return value.GetChildAtIndex(index)


def _child_by_name(value, name):
    try:
        child = value.GetChildMemberWithName(name)
        if _valid_lldb_value(child):
            return child
    except Exception:
        pass
    return None


def _unsigned_value(value, default=None):
    if not _valid_lldb_value(value) or value.GetValue() is None:
        return default

    try:
        return value.GetValueAsUnsigned(default if default is not None else 0)
    except Exception:
        return default


def _unsigned_child(value, index, default=None):
    child = _child_at(value, index)
    if child is None:
        return default
    return _unsigned_value(child, default)


def _reasonable_size(size):
    return size is not None and size <= MAX_REASONABLE_COLLECTION_SIZE


def _valid_pointer_value(value):
    return _valid_lldb_value(value) and value.GetValueAsUnsigned(0) != 0


def _valid_element_storage(pointer, element_type, size):
    if size == 0:
        return True
    if not _valid_pointer_value(pointer):
        return False
    return _valid_lldb_value(pointer) and element_type.IsValid() and element_type.GetByteSize() > 0


def _read_uint32(target, address):
    if address == lldb.LLDB_INVALID_ADDRESS:
        return None

    process = target.GetProcess()
    if not process.IsValid():
        return None

    error = lldb.SBError()
    data = process.ReadMemory(address, 4, error)
    if not error.Success() or len(data) != 4:
        return None

    try:
        byte_order = target.GetByteOrder()
        endian = 'big' if byte_order == lldb.eByteOrderBig else 'little'
    except Exception:
        endian = 'little'
    return int.from_bytes(bytes(data), byteorder=endian)


def crystal_type_id(target, type_name):
    if type_name == 'Nil':
        return 0

    key = (target.GetProcess().GetProcessID(), type_name)
    if key in TYPE_ID_SYMBOL_CACHE:
        return TYPE_ID_SYMBOL_CACHE[key]

    result = None
    symbols = target.FindSymbols('%s:type_id' % type_name)
    for index in range(symbols.GetSize()):
        symbol = symbols.GetContextAtIndex(index).GetSymbol()
        if not symbol.IsValid():
            continue

        address = symbol.GetStartAddress().GetLoadAddress(target)
        result = _read_uint32(target, address)
        if result is not None:
            break

    TYPE_ID_SYMBOL_CACHE[key] = result
    return result


def dereference(value):
    if value.TypeIsPointerType():
        return value.Dereference()
    return value


def raw_value(value):
    if not _available_lldb_value(value) or _has_null_pointer(value):
        return None
    return dereference(value).GetNonSyntheticValue()


def value_summary(value):
    summary = value.GetSummary()
    if summary is not None:
        return summary

    raw = value.GetValue()
    if raw is not None:
        return raw

    return value.GetTypeName()


def live_hash_entries(value, limit=None):
    hash_raw = raw_value(value)
    if hash_raw is None:
        return None, []

    size = _unsigned_child(hash_raw, 3)
    if not _reasonable_size(size):
        return None, []
    if size == 0:
        return hash_raw, []

    first = _unsigned_child(hash_raw, 0)
    deleted_count = _unsigned_child(hash_raw, 4)
    if first is None or deleted_count is None or not _reasonable_size(deleted_count):
        return None, []

    total_entries = size + deleted_count
    if not _reasonable_size(total_entries):
        return None, []

    entries = _child_at(hash_raw, 1)
    if entries is None:
        return None, []

    entry_type = entries.GetType().GetPointeeType()
    entry_size = entry_type.GetByteSize()
    if not _valid_element_storage(entries, entry_type, total_entries):
        return None, []

    target_size = min(size, MAX_SYNTHETIC_CHILDREN if limit is None else limit)
    result = []

    if first == deleted_count:
        last = first + target_size
        for entry_index in range(first, last):
            offset = entry_size * entry_index
            result.append(entries.CreateChildAtOffset('', offset, entry_type))
        return hash_raw, result

    entry_index = first
    scanned = 0
    while entry_index < total_entries and len(result) < target_size and scanned < MAX_HASH_SCAN:
        offset = entry_size * entry_index
        entry = entries.CreateChildAtOffset('', offset, entry_type)
        if entry.GetChildAtIndex(0).GetValueAsUnsigned() != 0:
            result.append(entry)
        entry_index += 1
        scanned += 1

    return hash_raw, result

class CrystalArraySyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.buffer = None
        self.size = 0
        self.type = None
        self._updated = False

    def update(self):
        value = raw_value(self.valobj)
        if value is None:
            self.size = 0
            self.buffer = None
            self._updated = True
            return
        self.type = value.GetType()
        self.size = _unsigned_child(value, 0, 0)
        self.buffer = _child_at(value, 3)
        if not _reasonable_size(self.size):
            self.size = 0
            self.buffer = None
        self._updated = True

    def _ensure_updated(self):
        if not self._updated:
            self.update()

    def num_children(self):
        self._ensure_updated()
        size = 0 if self.size is None else self.size
        return min(size, MAX_SYNTHETIC_CHILDREN)

    def has_children(self):
        return self.num_children() > 0

    def get_child_index(self, name):
        try:
            return int(name.lstrip('[').rstrip(']'))
        except:
            return -1

    def get_child_at_index(self, index):
        self._ensure_updated()
        if index >= self.size or index >= MAX_SYNTHETIC_CHILDREN:
            return None
        try:
            if self.buffer is None:
                return None
            elementType = self.buffer.GetType().GetPointeeType()
            if not _valid_element_storage(self.buffer, elementType, self.size):
                return None
            offset = elementType.GetByteSize() * index
            return self.buffer.CreateChildAtOffset('[' + str(index) + ']', offset, elementType)
        except Exception as e:
            print('Got exception %s' % (str(e)))
            return None


def CrystalArray_SummaryProvider(value, dict):
    try:
        value = raw_value(value)
        if value is None:
            return None
        size = _unsigned_child(value, 0, 0)
        if not _reasonable_size(size):
            return None
        if size == 0:
            return '[]'

        buffer = _child_at(value, 3)
        if buffer is None:
            return None

        element_type = buffer.GetType().GetPointeeType()
        element_size = element_type.GetByteSize()
        if not _valid_element_storage(buffer, element_type, size):
            return None

        limit = min(size, 5)
        items = []

        for index in range(limit):
            child = buffer.CreateChildAtOffset('[%d]' % index, element_size * index, element_type)
            items.append(value_summary(child))

        if size > limit:
            items.append('... (%d total)' % size)

        return '[%s]' % ', '.join(items)
    except Exception as e:
        return 'Array(...) (error: %s)' % str(e)

def findType(name, module):
    cachedTypes = module.GetTypes()
    for idx in range(cachedTypes.GetSize()):
        type = cachedTypes.GetTypeAtIndex(idx)
        if type.name == name:
            return type
    return None


def CrystalString_SummaryProvider(value, dict):
    try:
        if not _available_lldb_value(value) or _has_null_pointer(value):
            return None
        if value.TypeIsPointerType():
            if value.GetValueAsUnsigned(0) == 0:
                return None
            value = value.Dereference()

        value = value.GetNonSyntheticValue()
        byte_size = value.GetChildAtIndex(0).GetValue()
        length = value.GetChildAtIndex(1).GetValue()
        buffer = value.GetChildAtIndex(2)
        if byte_size is None or length is None or not buffer.IsValid():
            return None

        byte_size = int(byte_size)
        length = int(length)
        length = byte_size or length
        str_addr = buffer.GetLoadAddress()
        if str_addr == lldb.LLDB_INVALID_ADDRESS:
            return None

        error = lldb.SBError()
        val = value.GetTarget().GetProcess().ReadCStringFromMemory(str_addr, length + 1, error)
        if not error.Success():
            return None
        return '"%s"' % val
    except Exception:
        return None


class CrystalHashSyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.entries = []
        self._updated = False

    def update(self):
        hash_raw, entries = live_hash_entries(self.valobj)
        if hash_raw is None:
            self.entries = []
            self._updated = True
            return
        size = int(hash_raw.GetChildAtIndex(3).GetValueAsUnsigned())
        self.entries = []

        for entry in entries:
            key = entry.GetChildAtIndex(1)
            value = entry.GetChildAtIndex(2)
            child = value.Clone('[%s]' % value_summary(key))
            if child.IsValid():
                self.entries.append(child)

            if len(self.entries) >= size:
                break

        self._updated = True

    def _ensure_updated(self):
        if not self._updated:
            self.update()

    def num_children(self):
        self._ensure_updated()
        return len(self.entries)

    def has_children(self):
        return self.num_children() > 0

    def get_child_index(self, name):
        self._ensure_updated()

        for index, child in enumerate(self.entries):
            if child.GetName() == name:
                return index

        try:
            return int(name.lstrip('[').rstrip(']'))
        except:
            return -1

    def get_child_at_index(self, index):
        self._ensure_updated()
        if index >= len(self.entries):
            return None
        try:
            return self.entries[index]
        except Exception as e:
            print('Hash formatter error: %s' % (str(e)))
            return None


def CrystalHash_SummaryProvider(value, dict):
    try:
        hash_raw, entries = live_hash_entries(value, limit = 5)
        if hash_raw is None:
            return None
        size = _unsigned_child(hash_raw, 3, 0)

        if size == 0:
            return '{}'

        pairs = []
        for entry in entries:
            key = entry.GetChildAtIndex(1)
            item_value = entry.GetChildAtIndex(2)
            pairs.append('%s => %s' % (value_summary(key), value_summary(item_value)))

        if size > len(entries):
            pairs.append('... (%d total)' % size)

        return '{%s}' % ', '.join(pairs)
    except Exception as e:
        return 'Hash(...) (error: %s)' % str(e)


def CrystalSet_SummaryProvider(value, dict):
    try:
        if not _available_lldb_value(value) or _has_null_pointer(value):
            return None
        value = dereference(value)
        hash_ptr = _child_at(value, 0)
        if hash_ptr is None:
            return None
        hash_raw, entries = live_hash_entries(hash_ptr, limit = 10)
        if hash_raw is None:
            return None
        size = _unsigned_child(hash_raw, 3, 0)

        if size == 0:
            return 'Set{}'

        elements = []
        for entry in entries:
            elements.append(value_summary(entry.GetChildAtIndex(1)))

        if size > 10:
            return 'Set{' + ', '.join(elements) + ', ... (%d total)}' % size
        else:
            return 'Set{' + ', '.join(elements) + '}'
    except Exception as e:
        return 'Set{...} (error: %s)' % str(e)


def union_fields(value):
    value = raw_value(value)
    if value is None:
        return None, None, None, None

    type_id_value = _child_by_name(value, 'type_id')
    union_value = _child_by_name(value, 'union')
    if type_id_value is None or union_value is None:
        return None, None, None, None

    type_id = _unsigned_value(type_id_value)
    if type_id is None:
        return None, None, None, None

    return value, type_id_value, union_value, type_id


def selected_union_member(value):
    _, _, union_value, type_id = union_fields(value)
    if type_id is None:
        return None, None, None
    if type_id == 0:
        return 'Nil', None, type_id

    target = union_value.GetTarget()
    for index in range(union_value.GetNumChildren()):
        child = union_value.GetChildAtIndex(index)
        if not _valid_lldb_value(child):
            continue

        type_name = child.GetName()
        if type_name is None:
            continue

        if crystal_type_id(target, type_name) == type_id:
            return type_name, child, type_id

    return None, None, type_id


def raw_children(value):
    value = raw_value(value)
    if value is None:
        return []

    result = []
    for index in range(min(value.GetNumChildren(), MAX_SYNTHETIC_CHILDREN)):
        child = value.GetChildAtIndex(index)
        if _valid_lldb_value(child):
            result.append(child)
    return result


class CrystalUnionSyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.children = []
        self._updated = False

    def update(self):
        type_name, value, type_id = selected_union_member(self.valobj)
        self.children = []
        if value is not None:
            child = value.Clone(type_name)
            if child.IsValid():
                self.children.append(child)
        elif type_id is not None and type_id != 0:
            _, type_id_value, union_value, _ = union_fields(self.valobj)
            self.children = [child for child in (type_id_value, union_value) if child is not None]
        elif type_id is None:
            self.children = raw_children(self.valobj)
        self._updated = True

    def _ensure_updated(self):
        if not self._updated:
            self.update()

    def num_children(self):
        self._ensure_updated()
        return len(self.children)

    def has_children(self):
        return self.num_children() > 0

    def get_child_index(self, name):
        self._ensure_updated()
        for index, child in enumerate(self.children):
            if child.GetName() == name:
                return index
        return -1

    def get_child_at_index(self, index):
        self._ensure_updated()
        if index >= len(self.children):
            return None
        return self.children[index]


def CrystalUnion_SummaryProvider(value, dict):
    try:
        type_name, member, type_id = selected_union_member(value)
        if type_id is None:
            return None
        if type_id == 0:
            return 'Nil'
        if member is None:
            return None
        return value_summary(member)
    except Exception:
        return None


def CrystalRange_SummaryProvider(value, dict):
    try:
        if not _available_lldb_value(value) or _has_null_pointer(value):
            return None
        value = dereference(value)
        begin_val = value.GetChildAtIndex(0).GetValue()
        end_val = value.GetChildAtIndex(1).GetValue()
        exclusive = value.GetChildAtIndex(2).GetValueAsUnsigned() != 0

        if exclusive:
            return '%s...%s' % (begin_val, end_val)
        else:
            return '%s..%s' % (begin_val, end_val)
    except Exception as e:
        return 'Range(...) (error: %s)' % str(e)


def __lldb_init_module(debugger, dict):
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalArraySyntheticProvider -x "^Array\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -e -F crystal_formatters.CrystalArray_SummaryProvider -x "^Array\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalUnionSyntheticProvider -x "^\(.+ \| .+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalUnion_SummaryProvider -x "^\(.+ \| .+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalString_SummaryProvider -x "^(String|\(String \| Nil\))(\s*\**)?$" -w Crystal')
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalHashSyntheticProvider -x "^Hash\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -e -F crystal_formatters.CrystalHash_SummaryProvider -x "^Hash\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalSet_SummaryProvider -x "^Set\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalRange_SummaryProvider -x "^Range\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type category enable Crystal')
