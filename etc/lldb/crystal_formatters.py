import lldb
import os


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


def _has_non_null_pointer(value):
    return not value.TypeIsPointerType() or value.GetValueAsUnsigned(0) != 0


def dereference(value):
    if value.TypeIsPointerType():
        return value.Dereference()
    return value


def raw_value(value):
    if not _available_lldb_value(value) or not _has_non_null_pointer(value):
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

    size = int(hash_raw.GetChildAtIndex(3).GetValueAsUnsigned())
    if size == 0:
        return hash_raw, []

    first = int(hash_raw.GetChildAtIndex(0).GetValueAsUnsigned())
    deleted_count = int(hash_raw.GetChildAtIndex(4).GetValueAsUnsigned())
    total_entries = size + deleted_count
    entries = hash_raw.GetChildAtIndex(1)
    entry_type = entries.GetType().GetPointeeType()
    entry_size = entry_type.GetByteSize()
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
        self.size = value.GetChildAtIndex(0).GetValueAsUnsigned(0)
        self.buffer = value.GetChildAtIndex(3)
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
        size = value.GetChildAtIndex(0).GetValueAsUnsigned(0)
        if size == 0:
            return '[]'

        buffer = value.GetChildAtIndex(3)
        element_type = buffer.GetType().GetPointeeType()
        element_size = element_type.GetByteSize()
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
        if not _available_lldb_value(value) or not _has_non_null_pointer(value):
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
        size = int(hash_raw.GetChildAtIndex(3).GetValueAsUnsigned())

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
        if not _available_lldb_value(value) or not _has_non_null_pointer(value):
            return None
        value = dereference(value)
        hash_ptr = value.GetChildAtIndex(0)
        hash_raw, entries = live_hash_entries(hash_ptr, limit = 10)
        if hash_raw is None:
            return None
        size = int(hash_raw.GetChildAtIndex(3).GetValueAsUnsigned())

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


def CrystalRange_SummaryProvider(value, dict):
    try:
        if not _available_lldb_value(value) or not _has_non_null_pointer(value):
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
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalString_SummaryProvider -x "^(String|\(String \| Nil\))(\s*\**)?$" -w Crystal')
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalHashSyntheticProvider -x "^Hash\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -e -F crystal_formatters.CrystalHash_SummaryProvider -x "^Hash\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalSet_SummaryProvider -x "^Set\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalRange_SummaryProvider -x "^Range\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type category enable Crystal')
