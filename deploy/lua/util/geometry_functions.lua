--[[ geometry_functions.lua

	Utilities for generating geometry meshes.
]]

geometry_functions = {}

function geometry_functions.combine_meshes(meshes)
    local v = {}
    local n = {}
    local t = {}
    local f = {}

    for _,m in pairs(meshes) do
        local v1,n1,t1,f1 = m[1], m[2], m[3], m[4]
        local b = #v/3 -- xyz tuples
        for i=1,#v1+1 do
            table.insert(v, v1[i])
            table.insert(n, n1[i])
            table.insert(t, t1[i])
        end
        for i=1,#f1 do
            table.insert(f, f1[i]+b)
        end
    end

    return v,n,t,f
end

-- Generates capless cylinder with circle in xy, one circle centered
-- on origin and one on 0,0,1.
function geometry_functions.generate_cylinder(slices, stacks)
    local v = {}
    local n = {}
    local t = {}
    for stack=0,stacks do
        local u = stack / stacks
        for slice=0,slices-1 do
            local phase = slice / slices
            local rot = 2 * math.pi * (phase+.5)
            local x,y = math.sin(rot), math.cos(rot)
            table.insert(v, x)
            table.insert(v, y)
            table.insert(v, u)
            table.insert(n, x)
            table.insert(n, y)
            table.insert(n, 0)
            table.insert(t, phase)
            table.insert(t, u)
        end
    end

    local f = {}
    local b = 0
    for stack=0,stacks-1 do
        for slice=0,slices-1 do
            local nexts = slice + 1
            if nexts == slices then nexts = 0 end
            table.insert(f, b + slice + slices)
            table.insert(f, b + nexts)
            table.insert(f, b + slice)
            table.insert(f, b + slice + slices)
            table.insert(f, b + nexts + slices)
            table.insert(f, b + nexts)
        end
        b = b + slices
    end

    return v,n,t,f
end

-- Generates hemisphere centered on origin
function geometry_functions.generate_hemisphere(slices, stacks)
    local v = {}
    local n = {}
    local t = {}
    for stack=0,stacks do
        local u = stack / stacks
        for slice=0,slices-1 do
            local phase = slice / slices
            local theta = 2 * math.pi * (phase+.5)
            local phi = 0.5*math.pi * u
            local x = u * math.sin(theta) --*math.sin(phi)
            local y = u * math.cos(theta) --*math.sin(phi)
            local z = -math.sqrt(1 - u*u)
            table.insert(v, x)
            table.insert(v, y)
            table.insert(v, z)
            table.insert(n, x)
            table.insert(n, y)
            table.insert(n, z)
            table.insert(t, phase)
            table.insert(t, u)
        end
    end

    local f = {}
    local b = 0
    for stack=0,stacks-1 do
        for slice=0,slices-1 do
            local nexts = slice + 1
            if nexts == slices then nexts = 0 end
            table.insert(f, b + slice + slices)
            table.insert(f, b + nexts)
            table.insert(f, b + slice)
            table.insert(f, b + slice + slices)
            table.insert(f, b + nexts + slices)
            table.insert(f, b + nexts)
        end
        b = b + slices
    end

    return v,n,t,f
end

function geometry_functions.generate_disc(slices, stacks)
    local v = {}
    local n = {}
    local t = {}
    -- center point
    table.insert(v, 0)
    table.insert(v, 0)
    table.insert(v, 0)
    table.insert(n, 0)
    table.insert(n, 0)
    table.insert(n, -1)
    table.insert(t, 0)
    table.insert(t, 0)
    for j=0,stacks do
        for i=0,slices do
            local phase = i / slices
            local rot = 2 * math.pi * (phase+.5)
            local x,y = math.sin(rot), math.cos(rot)
            local r = (j+1)/stacks
            table.insert(v, r*x)
            table.insert(v, r*y)
            table.insert(v, 0)
            table.insert(n, 0)
            table.insert(n, 0)
            table.insert(n, -1)
            table.insert(t, phase)
            table.insert(t, j/stacks)
        end
    end

    local f = {}
    -- inner ring
    for i=0,slices do
        table.insert(f, 0)
        table.insert(f, i+1)
        table.insert(f, i)
    end
    for i=0,(stacks-1)*(slices+1)  do
        table.insert(f, i)
        table.insert(f, i+1)
        table.insert(f, i+slices+1)
        table.insert(f, i+slices+1)
        table.insert(f, i+1)
        table.insert(f, i+slices+2)
    end

    return v,n,t,f
end


function geometry_functions.generate_capsule(slices, stacks, length)
    local othercap = {geometry_functions.generate_hemisphere(slices,stacks)}
    -- Translate cap to other end of cylinder
    local v = othercap[1]
    local n = othercap[2]
    local ct = #v/3
    for i=1,ct do
        -- flip x and z, effectively a rotate 180 around y
        v[3*i-2] = -v[3*i-2]
        v[3*i] = -v[3*i]
        n[3*i-2] = -n[3*i-2]
        n[3*i] = -n[3*i]
        -- Move along z axis
        v[3*i] = v[3*i] + length
    end

    local cyl = {geometry_functions.generate_cylinder(slices,stacks)}
    local v = cyl[1]
    local ct = #v/3
    for i=1,ct do
        -- Scale z axis
        v[3*i] = v[3*i] * length
    end

    local meshes = {
        {geometry_functions.generate_hemisphere(slices,stacks)},
        cyl,
        othercap,
    }
    return geometry_functions.combine_meshes(meshes)
end

function geometry_functions.generate_capped_cylinder(slices, stacks, length)
    local cyl = {geometry_functions.generate_cylinder(slices,stacks)}
    local v = cyl[1]
    local ct = #v/3
    for i=1,ct do
        -- Scale z axis
        v[3*i] = v[3*i] * length
    end

    local othercap = {geometry_functions.generate_disc(slices,stacks)}
    -- Translate cap to other end of cylinder
    local v = othercap[1]
    local n = othercap[2]
    local ct = #v/3
    for i=1,ct do
        -- flip x and z, effectively a rotate 180 around y
        v[3*i-2] = -v[3*i-2]
        v[3*i] = -v[3*i]
        n[3*i-2] = -n[3*i-2]
        n[3*i] = -n[3*i]
        -- Move along z axis
        v[3*i] = v[3*i] + length
    end

    local meshes = {
        {geometry_functions.generate_disc(slices,stacks)},
        cyl,
        othercap,
    }
    return geometry_functions.combine_meshes(meshes)
end

return geometry_functions
