# Copyright 2020 Mattia Giambirtone
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Base structure for objects in JAPL, all
## types inherit from this simple structure

import ../memory
import strformat


type
    Chunk* = ref object
        ## A piece of bytecode.
        ## Consts represents the constants the code is referring to
        ## Code represents the bytecode
        ## Lines represents which lines the corresponding bytecode was one (1 to 1 correspondence)
        consts*: seq[ptr Obj]
        code*: seq[uint8]
        lines*: seq[int]
    ObjectType* {.pure.} = enum
        ## All the possible object types
        String, Exception, Function,
        Class, Module, BaseObject,
        Integer, Float, Bool, Nan,
        Infinity, Nil
    Obj* = object of RootObj
        # The object that rules them all
        kind*: ObjectType
        hashValue*: uint32
    String* = object of Obj    # A string object
        str*: ptr UncheckedArray[char]  # TODO -> Unicode support
        len*: int
    Integer* = object of Obj
        # An integer object
        intValue: int  # TODO: Bignum arithmetic
    Bool* = object of Integer
        boolValue: bool  # If the boolean is true or false
    Nil* = object of Bool
    Float* = object of Integer
        # A float object
        floatValue: float
    Infinity* = object of Float   # Inf is considered a float
        isNegative: bool  # This differentiates inf and -inf
    NotANumber* = object of Float     # NaN is as well (IEEE 754)
    Function* = object of Obj
        name*: ptr String
        arity*: int
        optionals*: int
        defaults*: seq[ptr Obj]
        chunk*: Chunk
    JAPLException* = object of Obj
        errName*: ptr String
        message*: ptr String


proc newChunk*(): Chunk =
    ## The constructor for the type Chunk
    result = Chunk(consts: @[], code: @[], lines: @[])


proc allocateObject*(size: int, kind: ObjectType): ptr Obj =
    ## Wrapper around reallocate to create a new generic JAPL object
    result = cast[ptr Obj](reallocate(nil, 0, size))
    result.kind = kind


template allocateObj*(kind: untyped, objType: ObjectType): untyped =
    ## Wrapper around allocateObject to cast a generic object
    ## to a more specific type
    cast[ptr kind](allocateObject(sizeof kind, objType))


proc objType*(obj: ptr Obj): ObjectType =
    ## Returns the type of the object
    return obj.kind


# Methods for string objects

proc stringify*(s: ptr String): string =
    result = ""
    for i in 0..<s.len:
        result = result & (&"{s.str[i]}")

proc isFalsey*(s: ptr String): bool =
    result = s.len == 0


proc hash*(self: ptr String): uint32 =
    result = 2166136261u32
    var i = 0
    while i < self.len:
        result = result xor uint32 self.str[i]
        result *= 16777619
        i += 1
    return result


proc eq*(a: ptr String, b: ptr String): bool =
    if a.len != b.len:
        return false
    elif a.hash != b.hash:
        return false
    for i in 0..a.len - 1:
        if a.str[i] != b.str[i]:
            return false
    return true


proc newString*(str: string): ptr String =
    # TODO -> Unicode
    result = allocateObj(String, ObjectType.String)
    result.str = allocate(UncheckedArray[char], char, len(str))
    for i in 0..len(str) - 1:
        result.str[i] = str[i]
    result.len = len(str)
    result.hashValue = result.hash()


proc typeName*(s: ptr String): string =
    return "string"


proc asStr*(s: string): ptr Obj =
    ## Creates a string object
    result = newString(s)

# End of string object methods


# Integer object methods

proc stringify(self: ptr Integer): string = 
    result = $self.intValue


proc stringify(self: ptr Float): string = 
    result = $self.floatValue


# End of integer object methods



# Function object methods

type
    FunctionType* {.pure.} = enum
        Func, Script


proc newFunction*(name: string = "", chunk: Chunk = newChunk(), arity: int = 0): ptr Function =
    result = allocateObj(Function, ObjectType.Function)
    if name.len > 1:
        result.name = newString(name)
    else:
        result.name = nil
    result.arity = arity
    result.chunk = chunk


proc isFalsey*(fn: ptr Function): bool =
    return false


proc valuesEqual*(a, b: ptr Function): bool =
    result = a.name.stringify == b.name.stringify


proc typeName*(self: ptr Function): string =
    result = "function"


proc stringify*(fn: ptr Function): string =
    if fn.name != nil:
        result = "<function " & stringify(fn.name) & ">"  # idk why this doesn't work with &"{...}", too tired to investigate
    else:
        result = "<code object>"


## Generic base methods


proc stringify*(obj: ptr Obj): string =
    ## Returns a string representation
    ## of the object
    if obj.kind == ObjectType.String:
        result = cast[ptr String](obj).stringify()
    elif obj.kind == ObjectType.Function:
        result = cast[ptr Function](obj).stringify()
    elif obj.kind == ObjectType.Integer:
        result = cast[ptr Integer](obj).stringify()
    elif obj.kind == ObjectType.Float:
        result = cast[ptr Float](obj).stringify()
    elif obj.kind == ObjectType.Bool:
        result = cast[ptr Bool](obj).stringify()
    elif obj.kind == ObjectType.Nan:
        result = cast[ptr NotANumber](obj).stringify()
    elif obj.kind == ObjectType.Infinity:
        result = cast[ptr Infinity](obj).stringify()
    elif obj.kind == ObjectType.BaseObject:
        result = "<object (built-in type)>"
    else:
        discard  # Unreachable


proc isFalsey*(obj: ptr Obj): bool =
    ## Returns true if the given
    ## object is falsey

    result = false


proc typeName*(obj: ptr Obj): string =
    ## This method should return the
    ## name of the object type
    result = "object"


proc bool*(obj: ptr Obj): bool =
    ## Returns wheter the object should
    ## be considered a falsey obj
    ## or not. Returns true if the
    ## object is truthy, or false
    ## if it is falsey
    result = false


proc eq*(a: ptr Obj, b: ptr Obj): bool =
    ## Compares two objects for equality
    result = a.kind == b.kind


proc hash*(self: ptr Obj): uint32 =
    # TODO: Make this actually useful
    result = 2166136261u32


proc add(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self + other
    ## or nil if the operation is unsupported
    result = nil  # Not defined for base objects!


proc sub(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self - other
    ## or nil if the operation is unsupported
    result = nil


proc mul(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self * other
    ## or nil if the operation is unsupported
    result = nil


proc trueDiv(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self / other
    ## or nil if the operation is unsupported
    result = nil


proc exp(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self ** other
    ## or nil if the operation is unsupported
    result = nil


proc binaryAnd(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self & other
    ## or nil if the operation is unsupported
    result = nil


proc binaryOr(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self | other
    ## or nil if the operation is unsupported
    result = nil


proc binaryNot(self: ptr Obj): ptr Obj =
    ## Returns the result of ~self
    ## or nil if the operation is unsupported
    result = nil


proc binaryXor(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self ^ other
    ## or nil if the operation is unsupported
    result = nil

    
proc isNil*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL nil object
    result = obj.kind == ObjectType.Nil


proc isBool*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL bool
    result = obj.kind == ObjectType.Bool


proc isInt*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL integer
    result = obj.kind == ObjectType.Integer


proc isFloat*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL float
    result = obj.kind == ObjectType.Float


proc isInf*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL inf object
    result = obj.kind == ObjectType.Infinity


proc isNan*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL nan object
    result = obj.kind == ObjectType.Nan


proc isNum*(obj: ptr Obj): bool =
    ## Returns true if the given obj is
    ## either a JAPL number, nan or inf
    result = isInt(obj) or isFloat(obj) or isInf(obj) or isNan(obj)


proc isStr*(obj: ptr Obj): bool =
    ## Returns true if the given object is a JAPL string
    result = obj.kind == ObjectType.String


proc toBool*(obj: ptr Obj): bool =
    ## Converts a JAPL bool to a nim bool
    result = cast[ptr Bool](obj).boolValue


proc toInt*(obj: ptr Obj): int =
    ## Converts a JAPL int to a nim int
    result = cast[ptr Integer](obj).intValue


proc toFloat*(obj: ptr Obj): float =
    ## Converts a JAPL float to a nim float
    result = cast[ptr Float](obj).floatValue

# TODO ambiguous naming: conflict with toString(obj: obj) that does JAPL->JAPL
proc toStr*(obj: ptr Obj): string =
    ## Converts a JAPL string into a nim string
    var strObj = cast[ptr String](obj)
    for i in 0..strObj.str.len - 1:
        result.add(strObj.str[i])


proc asInt*(n: int): ptr Integer =
    ## Creates an int object
    result = allocateObj(Integer, ObjectType.Integer)
    result.intValue = n


proc asFloat*(n: float): ptr Float =
    ## Creates a float object (double)
    result = allocateObj(Float, ObjectType.Float)
    result.floatValue = n


proc asBool*(b: bool): ptr Bool =
    ## Creates a boolean object
    result = allocateObj(Bool, ObjectType.Bool)
    result.boolValue = b


proc asNil*(): ptr Nil = 
    ## Creates a nil object
    result = allocateObj(Nil, ObjectType.Nil)


proc asNan*(): ptr NotANumber = 
    ## Creates a nil object
    result = allocateObj(NotANumber, ObjectType.Nan)


proc asInf*(): ptr Infinity =
    ## Creates a nil object
    result = allocateObj(Infinity, ObjectType.Infinity)


proc asObj*(obj: ptr Obj): ptr Obj =
    ## Creates a generic JAPL object
    result = allocateObj(Obj, ObjectType.BaseObject)

proc newIndexError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("IndexError")
    result.message = newString(message)


proc newReferenceError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("ReferenceError")
    result.message = newString(message)


proc newInterruptedError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("InterruptedError")
    result.message = newString(message)


proc newRecursionError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("RecursionError")
    result.message = newString(message)



proc newTypeError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("TypeError")
    result.message = newString(message)
