--[[ soundfx.lua

    Handles playback of sound effects using the BASS library
    http://www.un4seen.com/
]]
soundfx = {}

-- http://stackoverflow.com/questions/17877224/how-to-prevent-a-lua-script-from-failing-when-a-require-fails-to-find-the-scri
local function prequire(m)
  local ok, err = pcall(require, m)
  if not ok then return nil, err end
  return err
end

local bass, err = prequire("bass")
if bass == nil then
    print("soundfx.lua: Could not load Bass library: "..err)
end

local dataDir = nil
local samples = {}

function soundfx.setDataDirectory(dir)
    dataDir = dir
    print("soundfx.setDataDirectory",dir)

    -- Initialize audio library - BASS
    if bass then
        local init_ret = bass.BASS_Init(-1, 44100, 0, 0, nil)
    end
end

--TODO exit function

function soundfx.playSound(filename)
    if bass then
        if not samples[filename] then
            -- Load on demand
            print("Loading sample "..filename)
            local fullname = filename
            if dataDir then fullname = dataDir .. "/sounds/" .. fullname end
            samples[filename] = bass.BASS_SampleLoad(false, fullname, 0, 0, 16, 0)
        end

        local channel = bass.BASS_SampleGetChannel(samples[filename], false)
        bass.BASS_ChannelPlay(channel, false)
    end
end

return soundfx
