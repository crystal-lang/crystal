import gdb

class CrystalStringPrinter:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        bytesize = self.val['bytesize']
        buf = gdb.selected_inferior().read_memory(self.val['c'].address, bytesize)
        return buf.tobytes().decode('utf-8', errors='backslashreplace')

    def display_hint(self):
        return 'string'

class CrystalArrayPrinter:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        type = self.val.type
        if type.code == gdb.TYPE_CODE_PTR:
            type = type.target()
        return str(type)

    def children(self):
        for i in range(int(self.val['size'])):
            yield str(i), (self.val['buffer'] + i).dereference()

    def display_hint(self):
        return 'array'

class CrystalReferenceSubPrinter:
    def __init__(self, name, cls):
        self.name = name
        self.enabled = True
        self.cls = cls

    def recognize(self, val):
        type = val.type
        if type.code == gdb.TYPE_CODE_PTR:
            type = type.target()
        typename = type.name
        if typename is not None:
            if typename == self.name:
                return self.cls(val)
            if typename.startswith(self.name) and typename[len(self.name)] == '(':
                return self.cls(val)

class CrystalPrettyPrinter(gdb.printing.PrettyPrinter):
    def __init__(self):
        super(CrystalPrettyPrinter, self).__init__("CrystalStdlib", [])
        self.subprinters.append(CrystalReferenceSubPrinter("String", CrystalStringPrinter))
        self.subprinters.append(CrystalReferenceSubPrinter("Array", CrystalArrayPrinter))

    def __call__(self, val):
        for subprinter in self.subprinters:
            if subprinter.enabled:
                instance = subprinter.recognize(val)
                if instance is not None:
                    return instance

gdb.printing.register_pretty_printer(
    gdb.current_objfile(),
    CrystalPrettyPrinter(),
    replace=True)
