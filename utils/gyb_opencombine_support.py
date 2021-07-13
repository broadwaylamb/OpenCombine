def suffix_variadic(name, index, arity):
    return name + ('' if arity == 1 else str(index))

def list_with_suffix_variadic(name, arity):
    return [suffix_variadic(name, i, arity) for i in range(arity)]

def indent(input, space_count):
    padding = space_count * ' '
    return ''.join(padding + line for line in input.splitlines(True))
