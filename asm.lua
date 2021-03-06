local band, lshift = band, lshift

local InstructionTypes = { }

local sbxBias = 131071 -- (2^18 - 1) >> 1

function InstructionTypes.ABC(opcode, a, b, c)
    a = lshift(a, 6)
    b = lshift(b, 23)
    c = lshift(c, 14)
    return band(opcode + a + b + c, 2^32 - 1)
end

function InstructionTypes.ABx(opcode, a, bx)
    a = lshift(a, 6)
    bx = lshift(bx, 14)
    return band(opcode + a + bx, 2^32 - 1)
end

function InstructionTypes.AsBx(opcode, a, sbx)
    a = lshift(a, 6)
    sbx = sbx + sbxBias
    sbx = lshift(sbx, 14)
    return band(opcode + a + sbx, 2^32 - 1)
end

function InstructionTypes.AB(opcode, a, b)
    return InstructionTypes.ABC(opcode, a, b, 0)
end

function InstructionTypes.AC(opcode, a, c)
    return InstructionTypes.ABC(opcode, a, 0, c)
end

function InstructionTypes.A(opcode, a)
    return InstructionTypes.ABC(opcode, a, 0, 0)
end

function InstructionTypes.sBx(opcode, sbx)
    return InstructionTypes.AsBx(opcode, 0, sbx)
end

local Op = { }
Op.MOVE         = {opcode = 0, type = InstructionTypes.AB   }
Op.LOADK        = {opcode = 1, type = InstructionTypes.ABx  }
Op.LOADBOOL     = {opcode = 2, type = InstructionTypes.ABC  }
Op.LOADNIL      = {opcode = 3, type = InstructionTypes.AB   }
Op.GETUPVAL     = {opcode = 4, type = InstructionTypes.AB   }
Op.GETGLOBAL    = {opcode = 5, type = InstructionTypes.ABx  }
Op.GETTABLE     = {opcode = 6, type = InstructionTypes.ABC  }
Op.SETGLOBAL    = {opcode = 7, type = InstructionTypes.ABx  }
Op.SETUPVAL     = {opcode = 8, type = InstructionTypes.AB   }
Op.SETTABLE     = {opcode = 9, type = InstructionTypes.ABC  }
Op.NEWTABLE     = {opcode = 10, type = InstructionTypes.ABC }
Op.SELF         = {opcode = 11, type = InstructionTypes.ABC }
Op.ADD          = {opcode = 12, type = InstructionTypes.ABC }
Op.SUB          = {opcode = 13, type = InstructionTypes.ABC }
Op.MUL          = {opcode = 14, type = InstructionTypes.ABC }
Op.DIV          = {opcode = 15, type = InstructionTypes.ABC }
Op.MOD          = {opcode = 16, type = InstructionTypes.ABC }
Op.POW          = {opcode = 17, type = InstructionTypes.ABC }
Op.UNM          = {opcode = 18, type = InstructionTypes.AB  }
Op.NOT          = {opcode = 19, type = InstructionTypes.AB  }
Op.LEN          = {opcode = 20, type = InstructionTypes.AB  }
Op.CONCAT       = {opcode = 21, type = InstructionTypes.ABC }
Op.JMP          = {opcode = 22, type = InstructionTypes.sBx }
Op.EQ           = {opcode = 23, type = InstructionTypes.ABC }
Op.LT           = {opcode = 24, type = InstructionTypes.ABC }
Op.LE           = {opcode = 25, type = InstructionTypes.ABC }
Op.TEST         = {opcode = 26, type = InstructionTypes.AC  }
Op.TESTSET      = {opcode = 27, type = InstructionTypes.ABC }
Op.CALL         = {opcode = 28, type = InstructionTypes.ABC }
Op.TAILCALL     = {opcode = 29, type = InstructionTypes.ABC }
Op.RETURN       = {opcode = 30, type = InstructionTypes.AB  }
Op.FORLOOP      = {opcode = 31, type = InstructionTypes.AsBx}
Op.FORPREP      = {opcode = 32, type = InstructionTypes.AsBx}
Op.TFORLOOP     = {opcode = 33, type = InstructionTypes.AC  }
Op.SETLIST      = {opcode = 34, type = InstructionTypes.ABC }
Op.CLOSE        = {opcode = 35, type = InstructionTypes.A   }
Op.CLOSURE      = {opcode = 36, type = InstructionTypes.ABx }
Op.VARARG       = {opcode = 37, type = InstructionTypes.AB  }
for k,v in pairs(Op) do
    v.name = k
end

function makeChunkStream(numParams)
    local stream = { }

    local lastIndex = 0
    local constants = { }
    local sourceLinePositions = {}
    local nilIndex = nil
    local instns = { }
    local register = numParams - 1
    local maxRegister = register -- just tracking the highest we go

    local debugComments = { }
    local debugAnnotations = { }
    local debugCode = { }

    function stream.getMaxRegister()
        return maxRegister
    end

    function stream.comment(comment)
        debugComments[#instns + 1] = debugComments[#instns + 1] or {}
        table.insert(debugComments[#instns + 1], comment)
    end

    function stream.annotate(annot)
        debugAnnotations[#instns + 1] = debugAnnotations[#instns + 1] or {}
        table.insert(debugAnnotations[#instns + 1], annot)
    end

    function stream.getConstant(value)
        local index
        if value == nil then
            if not nilIndex then
                nilIndex = lastIndex
                lastIndex = lastIndex + 1
            end
            index = nilIndex
        else
            index = constants[value]
            if not index then
                constants[value] = lastIndex
                index = constants[value]
                lastIndex = lastIndex + 1
            end
        end
        return index
    end

    function stream.allocNilRK()
        local constant = stream.getConstant(nil)
        local rk
        if constant > 255 then
            rk = stream.alloc()
            stream.LOADK(rk, constant)
        else
            rk = bor(256, constant)
        end
        return rk
    end

    function stream.allocRK(value, ...)
        if value == nil then
            return
        end

        local constant = stream.getConstant(value)
        local rk
        if constant > 255 then
            rk = stream.alloc()
            stream.LOADK(rk, constant)
        else
            rk = bor(256, constant)
        end
        return rk, stream.allocRK(...)
    end

    function stream.freeRK(k, ...)
        if k == nil then
            return
        end
        if k < 256 then
            stream.free()
        end
        stream.freeRK(...)
    end

    function stream.emit(op, ...)
        local ok, inst = pcall(op.type, op.opcode, ...)
        assert(ok, inst, 2)
        table.insert(instns, inst)
        table.insert(debugCode, "[" .. (#instns) .. "] " .. op.name .. " " .. table.concat({...}, " "))
        sourceLinePositions[#instns] = #instns
        return #instns
    end

    function stream.startJump()
        table.insert(instns, 0)
        table.insert(debugCode, "")
        sourceLinePositions[#instns] = #instns
        return {instruction = #instns}
    end

    function stream.startBackwardJump(startInstruction)
        return {instruction = startInstruction or #instns, backward = true}
    end

    function stream.fixJump(jump)
        if not jump.backward then
            local jumpID = jump.instruction
            instns[jumpID] = Op.JMP.type(Op.JMP.opcode, #instns - jumpID)
            debugCode[jumpID] = "[" .. (jumpID) .. "] JMP " .. (#instns - jumpID)
        else
            stream.JMP(jump.instruction - (#instns + 1))
        end
    end

    function stream.getInstructionCount()
        return #instns
    end

    function stream.alloc(n)
        n = n or 1
        local ret = { }
        for i = 1, n do
            register = register + 1
            maxRegister = math.max(register, maxRegister)
            ret[i] = register
            stream.createPool(register)
        end
        return unpack(ret)
    end

    function stream.free(n)
        n = n or 1
        local ret = { }
        for i = n, 1, -1 do
            ret[i] = register
            stream.removeFromPool(register)
            register = register - 1
        end
        return unpack(ret)
    end

    function stream.alignToRegister(n)
        n = n or 0
        if n <= register then
            return stream.free(register - n)
        else
            return stream.alloc(n - register)
        end
    end

    function stream.peek(n)
        return register - n
    end

    for k,op in pairs(Op) do
        stream[k] = function(...)
            return stream.emit(op, ...)
        end
    end

    -- value pools are lists of registers known to share the same value
    local valuePools = { }
    function stream.findPool(reg)
        for poolIndex,pool in ipairs(valuePools) do
            for registerIndex,r in ipairs(pool) do
                if r == reg then
                    return pool, registerIndex, poolIndex
                end
            end
        end
    end

    function stream.getPool(reg)
        local pool, registerIndex, poolIndex = stream.findPool(reg)
        if not pool then
            pool, registerIndex, poolIndex = stream.createPool(reg)
        end
        return pool, registerIndex, poolIndex
    end

    function stream.removeFromPool(reg)
        local pool, registerIndex, poolIndex = stream.findPool(reg)
        if pool then
            table.remove(pool, registerIndex)
            if #pool == 0 then
                table.remove(valuePools, poolIndex)
            end
        end
    end

    function stream.createPool(reg)
        stream.removeFromPool(reg)
        local pool = {reg}
        table.insert(valuePools, pool)
        return pool, 1, #valuePools
    end

    function stream.addToPool(add, to)
        local toPool = stream.getPool(to)
        if not toPool then
            toPool = stream.createPool(to)
        end
        local addPool = stream.getPool(add)
        if addPool and addPool ~= toPool then
            stream.removeFromPool(add)
        end
        if addPool ~= toPool then
            table.insert(toPool, add)
        end
        return toPool
    end

    function stream.clearValuePools()
        valuePools = { }
    end

    -- overwrite ops
    local assigners = {
        "LOADK",
        "LOADBOOL",
        "GETUPVAL",
        "GETGLOBAL",
        "GETTABLE",
        "NEWTABLE",
        "ADD",
        "SUB",
        "MUL",
        "DIV",
        "MOD",
        "POW",
        "UNM",
        "NOT",
        "LEN",
        "CONCAT"
    }
    for i,opName in ipairs(assigners) do
        local old = stream[opName]
        stream[opName] = function(rAssignTo, ...)
            stream.createPool(rAssignTo)
            return old(rAssignTo, ...)
        end
    end

    local oldMove = stream.MOVE
    function stream.MOVE(a, b)
        if a ~= b then
            stream.removeFromPool(a)
            stream.addToPool(a, b)
        end
        return oldMove(a, b)
    end

    local oldLoadnil = stream.LOADNIL
    function stream.LOADNIL(a, b)
        for r=a,b do
            stream.createPool(r)
        end
        return oldLoadnil(a, b)
    end

    local oldCall = stream.CALL
    function stream.CALL(a, b, c)
        local numArgs = b == 0 and stream.getMaxRegister() - a or b - 1
        local numReturns = c == 0 and stream.getMaxRegister() - a or c - 1
        for r=a, a + math.max(numArgs, numReturns) do
            stream.createPool(r)
        end
        return oldCall(a, b, c)
    end

    local oldClose = stream.CLOSE
    function stream.CLOSE(a)
        for i=a,stream.getMaxRegister() do
            stream.createPool(i)
        end
        return oldClose(a)
    end

    function stream.compile(platform, name)
        local dump = makeDumpster(platform)

        dump.dumpString(name)                               -- source name
        dump.dumpInteger(1)                                 -- line defined
        dump.dumpInteger(#instns)                           -- last line defined
        dump.dumpByte(0)                                    -- number of upvalues
        dump.dumpByte(numParams)                            -- number of parameters
        dump.dumpByte(0)                                    -- is vararg
        dump.dumpByte(math.max(2, maxRegister + 1))         -- max stack size
        dump.dumpInstructionsList(instns)                   -- instructions
        dump.dumpConstantsList(constants, nilIndex)         -- constants
        dump.dumpInteger(0)                                 -- empty function prototype list
        dump.dumpSourceLinePositions(sourceLinePositions)   -- line numbers
        dump.dumpInteger(0)                                 -- empty list of locals
        dump.dumpInteger(0)                                 -- empty list of upvalues

        return dump.toString()
    end

    function stream.getDebugCode()
        local code = ""
        for i,v in ipairs(debugCode) do
            if debugAnnotations[i] then
                code = code .. "\n" .. table.concat(debugAnnotations[i], "\n") .. "\n"
            end
            code = code .. (" "):rep(4) .. v
            if debugComments[i] then
                code = code .. (" "):rep(25 - #v) .. ";" .. table.concat(debugComments[i], "\n" .. (" "):rep(29) .. ";")
            end
            code = code .. "\n"
        end
        return code
    end

    -- utility functions
    function stream.asmLoadk(r, k)
        stream.LOADK(r, stream.getConstant(k))
    end

    function stream.asmClose()
        stream.CLOSE(stream.peek(0) + 1)
    end

    return stream
end