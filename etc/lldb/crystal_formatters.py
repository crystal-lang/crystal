import lldb


def dereference(value):
    if value.TypeIsPointerType():
        return value.Dereference()
    return value


def raw_value(value):
    return dereference(value).GetNonSyntheticValue()


def value_summary(value):
    summary = value.GetSummary()
    if summary is not None:
        return summary

    raw = value.GetValue()
    if raw is not None:
        return raw

    return value.GetTypeName()


def live_hash_entries(value, limit = None):
    hash_raw = raw_value(value)
    size = int(hash_raw.GetChildAtIndex(3).GetValueAsUnsigned())
    if size == 0:
        return hash_raw, []

    first = int(hash_raw.GetChildAtIndex(0).GetValueAsUnsigned())
    deleted_count = int(hash_raw.GetChildAtIndex(4).GetValueAsUnsigned())
    total_entries = size + deleted_count
    entries = hash_raw.GetChildAtIndex(1)
    entry_type = entries.GetType().GetPointeeType()
    entry_size = entry_type.GetByteSize()
    target_size = size if limit is None else min(size, limit)
    result = []

    if first == deleted_count:
        last = first + target_size
        for entry_index in range(first, last):
            offset = entry_size * entry_index
            result.append(entries.CreateChildAtOffset('', offset, entry_type))
        return hash_raw, result

    entry_index = first
    while entry_index < total_entries and len(result) < target_size:
        offset = entry_size * entry_index
        entry = entries.CreateChildAtOffset('', offset, entry_type)
        if entry.GetChildAtIndex(0).GetValueAsUnsigned() != 0:
            result.append(entry)
        entry_index += 1

    return hash_raw, result

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


class CrystalHashSyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.entries = []

    def update(self):
        _, self.entries = live_hash_entries(self.valobj)

    def num_children(self):
        return len(self.entries)

    def get_child_index(self, name):
        try:
            return int(name.lstrip('[').rstrip(']'))
        except:
            return -1

    def get_child_at_index(self, index):
        if index >= len(self.entries):
            return None
        try:
            return self.entries[index].Clone('[' + str(index) + ']')
        except Exception as e:
            print('Hash formatter error: %s' % (str(e)))
            return None


def CrystalSet_SummaryProvider(value, dict):
    try:
        value = dereference(value)
        hash_ptr = value.GetChildAtIndex(0)
        hash_raw, entries = live_hash_entries(hash_ptr, limit = 10)
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
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalString_SummaryProvider -x "^(String|\(String \| Nil\))(\s*\**)?$" -w Crystal')
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalHashSyntheticProvider -x "^Hash\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalSet_SummaryProvider -x "^Set\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalRange_SummaryProvider -x "^Range\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type category enable Crystal')
