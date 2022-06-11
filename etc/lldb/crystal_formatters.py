import lldb

class CrystalArraySyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.buffer = None
        self.size = 0

    def update(self):
        if self.valobj.type.is_pointer:
            self.valobj = self.valobj.Dereference()
        self.size = int(self.valobj.GetChildMemberWithName('size').value)
        self.buffer = self.valobj.GetChildMemberWithName('buffer')

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
    target = value.GetTarget()
    process = target.GetProcess()
    len = int(value.GetChildMemberWithName('length').value) or int(value.GetChildMemberWithName('bytesize').value)
    strAddr = value.GetChildMemberWithName('c').load_addr
    if "x86_64-pc-windows-msvc" == target.triple:
        # on windows, strings are prefixed by 4 bytes indicating the length
        strAddr = strAddr + 4
    val = process.ReadCStringFromMemory(strAddr, len + 1, error)
    return '"%s"' % val


def __lldb_init_module(debugger, dict):
    debugger.HandleCommand('type synthetic add -l crystal_formatters.CrystalArraySyntheticProvider -x "^Array\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand('type summary add -F crystal_formatters.CrystalString_SummaryProvider -x "^(String|\(String \| Nil\))(\s*\**)?$" -w Crystal')
    debugger.HandleCommand('type category enable Crystal')
