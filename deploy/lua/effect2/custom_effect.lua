--[[ custom_effect.lua

	Calls into effect_chain with a specific list of filters to initialize.
]]

custom_effect = {}

custom_effect.__index = custom_effect

require("effect2.effect_chain")

function custom_effect.new(...)
    -- Set custom filter chain parameters here
    local params = {}
    params.filter_names = {
        "posterize",
        "downsample",
    }
    return effect_chain.new(params)
end

return custom_effect
