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

## Main entry point for the JAPL language


import strformat
import parseopt
import os

import config
import vm
import types/japlNil
import types/typeutils
import types/methods


proc repl() =
    var bytecodeVM = initVM()
    echo JAPL_VERSION_STRING
    echo &"[Nim {NimVersion} on {hostOs} ({hostCPU})]"
    when DEBUG_TRACE_VM:
        echo "==== Runtime Constants ====\n"
        echo &"- FRAMES_MAX -> {FRAMES_MAX}"
        echo "==== Debugger started ====\n"
    var source = ""
    while true:
        try:
            stdout.write("=> ")
            source = stdin.readLine()
        except IOError:
            echo ""
            bytecodeVM.freeVM()
            break
        except KeyboardInterrupt:
            echo ""
            bytecodeVM.freeVM()
            break
        if source == "//clear" or source == "// clear":
            echo "\x1Bc"
            echo JAPL_VERSION_STRING
            echo &"[Nim {NimVersion} on {hostOs} ({hostCPU})]"
            continue
        elif source != "":
            discard bytecodeVM.interpret(source, "stdin")
            if not bytecodeVM.lastPop.isNil():
                echo stringify(bytecodeVM.lastPop)
                bytecodeVM.lastPop = cast[ptr Nil](bytecodeVM.cached[2])


proc main(file: var string = "", fromString: bool = false) =
    var source: string
    if file == "":
        repl()
        return   # We exit after the REPL has ran
    elif not fromString:
        var sourceFile: File
        try:
            sourceFile = open(filename=file)
        except IOError:
            echo &"Error: '{file}' could not be opened, probably the file doesn't exist or you don't have permission to read it"
            return
        try:
            source = readAll(sourceFile)
        except IOError:
            echo &"Error: '{file}' could not be read, probably you don't have the permission to read it"
    else:
        source = file
        file = "<string>"
    var bytecodeVM = initVM()
    discard bytecodeVM.interpret(source, file)
    bytecodeVM.freeVM()


when isMainModule:
    var optParser = initOptParser(commandLineParams())
    var file: string = ""
    var fromString: bool = false
    for kind, key, value in optParser.getopt():
        case kind:
            of cmdArgument:
                file = key
            of cmdLongOption:
                case key:
                    of "help":
                        echo HELP_MESSAGE
                        quit()
                    of "version":
                        echo JAPL_VERSION_STRING
                        quit()
                    else:
                        echo &"error: unkown option '{key}'"
                        quit()
            of cmdShortOption:
                case key:
                    of "h":
                        echo HELP_MESSAGE
                        quit()
                    of "v":
                        echo JAPL_VERSION_STRING
                        quit()
                    of "c":
                        file = key
                        fromString = true
                    else:
                        echo &"error: unkown option '{key}'"
                        quit()
            else:
                echo "usage: japl [filename]"
                quit()
    main(file, fromString)
