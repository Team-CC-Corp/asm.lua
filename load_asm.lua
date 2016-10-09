local dir = fs.getDir(shell.getRunningProgram())

local asmEnv = {
    asmDir = dir
}

function asmEnv.assert(condition, errMsg, level)
    if condition then return condition end
    if type(level) ~= "number" then
        level = 2
    elseif level <= 0 then
        level = 0
    else
        level = level + 1
    end
    error(errMsg or "Assertion failed!", level)
end

local files = {
    "numberlua.lua", -- Load before everything else
    "asm.lua",
    "bindump.lua",
    "platform.lua",
    "json.lua",
}

for i,v in ipairs(files) do
    assert(os.run(asmEnv, fs.combine(dir, v)), "Failed to load " .. v)
end

_G.asm = asmEnv