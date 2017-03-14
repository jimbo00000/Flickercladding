-- shaderfunctions2.lua
-- Return shader error messages on stack.

shaderfunctions2 = {}

local openGL = require("opengl")
local ffi = require("ffi")

-- Local copies of functions from shaderutils
-- so we can get back the errors and insert them into the editor.
function shaderfunctions2.load_and_compile_shader_source(src, type)
    local glIntv = ffi.typeof('GLint[?]')
    local glCharv = ffi.typeof('GLchar[?]')
    local glConstCharpp = ffi.typeof('const GLchar *[1]')

    -- Version replacement for various GL implementations 
    if ffi.os == "OSX" then
        -- MacOS X's inadequate GL support
        src = string.gsub(src, "#version 300 es", "#version 410")
        src = string.gsub(src, "#version 310 es", "#version 410")
    elseif string.match(ffi.string(gl.glGetString(GL.GL_VENDOR)), "ATI") then
        -- AMD's strict standard compliance
        src = string.gsub(src, "#version 300 es", "#version 430")
        src = string.gsub(src, "#version 310 es", "#version 430")
    end
    
    local sourcep = glCharv(#src + 1)
    ffi.copy(sourcep, src)
    local sourcepp = glConstCharpp(sourcep)

    local shaderObject = gl.glCreateShader(type)
    local errorText = nil

    gl.glShaderSource(shaderObject, 1, sourcepp, NULL)
    gl.glCompileShader(shaderObject)

    local ill = glIntv(0)
    gl.glGetShaderiv(shaderObject, GL.GL_INFO_LOG_LENGTH, ill)
    if (ill[0] > 1) then
        local cw = glIntv(0)
        local logp = glCharv(ill[0] + 1)
        gl.glGetShaderInfoLog(shaderObject, ill[0], cw, logp)
        errorText = ffi.string(logp)
        gl.glDeleteShader(shaderObject)
        return 0, errorText
    end

    local success = glIntv(0)
    gl.glGetShaderiv(shaderObject, GL.GL_COMPILE_STATUS, success);
    assert(success[0] == GL.GL_TRUE)

    return shaderObject, errorText
end

function shaderfunctions2.make_shader_from_source(sources)
    local glIntv = ffi.typeof('GLint[?]')
    local glCharv = ffi.typeof('GLchar[?]')

    local program = gl.glCreateProgram()

    -- Deleted shaders, once attached, will be deleted when program is.
    if type(sources.vsrc) == "string" then
        local vs, err = shaderfunctions2.load_and_compile_shader_source(sources.vsrc, GL.GL_VERTEX_SHADER)
        if err then return 0, err end
        gl.glAttachShader(program, vs)
        gl.glDeleteShader(vs)
    end
    if type(sources.fsrc) == "string" then
        local fs, err = shaderfunctions2.load_and_compile_shader_source(sources.fsrc, GL.GL_FRAGMENT_SHADER)
        if err then return 0, err end
        gl.glAttachShader(program, fs)
        gl.glDeleteShader(fs)
    end

    gl.glLinkProgram(program)

    local ill = glIntv(0)
    gl.glGetProgramiv(program, GL.GL_INFO_LOG_LENGTH, ill)
    if (ill[0] > 1) then
        local cw = glIntv(0)
        local logp = glCharv(ill[0] + 1)
        gl.glGetProgramInfoLog(program, ill[0], cw, logp)
        return 0, ffi.string(logp)
    end

    gl.glUseProgram(0)
    return program
end

return shaderfunctions2
