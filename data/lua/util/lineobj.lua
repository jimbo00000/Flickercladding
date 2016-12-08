-- lineobj.lua

lineobj = {}

lineobj.olist = {}
lineobj.vertlist = {}
lineobj.idxlist = {}

function lineobj.loadmodel(filename)
    local basevert = 1
    local numverts = 0

    local function addobject()
        numverts = #lineobj.idxlist - basevert - 1
        if #lineobj.vertlist > 0 then
            print("Object", numverts, basevert)
            table.insert(lineobj.olist, {numverts, basevert})
        end
        basevert = #lineobj.idxlist
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
                    table.insert(lineobj.vertlist, tonumber(toks[1]))
                    table.insert(lineobj.vertlist, tonumber(toks[2]))
                    table.insert(lineobj.vertlist, tonumber(toks[3]))
                end,
                ['l'] = function (x)
                    for i in pairs(toks) do
                        table.insert(lineobj.idxlist, i)
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

return lineobj
