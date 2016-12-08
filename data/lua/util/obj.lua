-- obj.lua

obj = {}

obj.olist = {}
obj.vertlist = {}
obj.idxlist = {}

-- http://wiki.interfaceware.com/534.html
function string_split(s, d)
    local t = {}
    local i = 0
    local f
    local match = '(.-)' .. d .. '()'
    
    if string.find(s, d) == nil then
        return {s}
    end
    
    for sub, j in string.gmatch(s, match) do
        i = i + 1
        t[i] = sub
        f = j
    end
    
    if i ~= 0 then
        t[i+1] = string.sub(s, f)
    end
    
    return t
end

function obj.loadmodel(filename)
    local basevert = 1
    local numverts = 0

    local function addobject()
        numverts = #obj.idxlist - basevert - 1
        if #obj.vertlist > 0 then
            print("Object", numverts, basevert)
            table.insert(obj.olist, {numverts, basevert})
        end
        basevert = #obj.idxlist
    end

    local inp = io.open(filename, "r")
    if inp then
        for line in inp:lines() do
            local toks = {}
            for w in string.gmatch(line, "%g+") do
                table.insert(toks, w)
            end

            local t = table.remove(toks, 1)
            local func_table = {
                ['o'] = addobject,
                ['v'] = function (x)
                    table.insert(obj.vertlist, tonumber(toks[1]))
                    table.insert(obj.vertlist, tonumber(toks[2]))
                    table.insert(obj.vertlist, tonumber(toks[3]))
                    table.insert(obj.vertlist, 1)
                end,
                ['l'] = function (x)
                    for i in pairs(toks) do
                        table.insert(obj.idxlist, i)
                    end
                end,
                ['f'] = function (x)
                    --print(toks)
                    for i,v in pairs(toks) do
                        --print(i,v)
                        local split = string_split(v, "/")
                        for x,y in pairs(split) do
                            --print("  "..y)
                        end
                        --print(split[1])
                        table.insert(obj.idxlist, tonumber(split[1])-1)
                    end
                end,
            }
            local f = func_table[t]
            if f then f() end
        end
        assert(inp:close())
        addobject()
    end
end

return obj
