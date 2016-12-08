-- shell_hacks.lua

local ffi = require("ffi")

function scandir_shellcmd(directory, cmd)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen(cmd..'"'..directory..'"')
    for filename in pfile:lines() do
        if filename ~= "." and filename ~= ".." then
            i = i + 1
            t[i] = filename
         end
    end
    pfile:close()
    return t
end

function scandir_portable_sorta(directory)
    local wincmd = 'dir /b '
    local poscmd = 'ls -a '
    local f = scandir_shellcmd(directory, poscmd)
    if #f == 0 then
        f = scandir_shellcmd(directory, wincmd)
    end
    return f
end


local files = scandir_portable_sorta("scene")
print(ffi.os, #files)
for k,v in pairs(files) do
    print(k,v)
end
