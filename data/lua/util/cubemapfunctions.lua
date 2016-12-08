-- cubemapfunctions.lua
cubemapfunctions = {}

local openGL = require("opengl")
local ffi = require("ffi")

function cubemapfunctions.allocate_fbo(w, h)
    fbo = {}
    fbo.w = w
    fbo.h = h

    local fboId = ffi.new("GLuint[1]")
    gl.glGenFramebuffers(1, fboId)
    fbo.id = fboId[0]
    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, fbo.id)

    local texId = ffi.new("GLuint[1]")
    gl.glGenTextures(1, texId)
    fbo.tex = texId[0]
    gl.glBindTexture(GL.GL_TEXTURE_CUBE_MAP, fbo.tex)
    gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR)
    gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR)
    gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_WRAP_S, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_WRAP_T, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_WRAP_R, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_COMPARE_MODE, GL.GL_COMPARE_REF_TO_TEXTURE)
    for i=0,5 do
        gl.glTexImage2D(GL.GL_TEXTURE_CUBE_MAP_POSITIVE_X+i,
                      0, GL.GL_RGBA8,
                      w, h, 0,
                      GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, nil)
    end

    gl.glBindTexture(GL.GL_TEXTURE_CUBE_MAP, 0)
    gl.glFramebufferTexture2D(GL.GL_FRAMEBUFFER, GL.GL_COLOR_ATTACHMENT0,
        GL.GL_TEXTURE_CUBE_MAP_POSITIVE_X, fbo.tex, 0)

    local status = gl.glCheckFramebufferStatus(GL.GL_FRAMEBUFFER)
    if status ~= GL.GL_FRAMEBUFFER_COMPLETE then
        print("ERROR: Framebuffer status: "..string.format("0x%x",status))
    end

    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, 0)
    return fbo
end

function cubemapfunctions.deallocate_fbo(fbo)
    if fbo == nil then return end
    local fboId = ffi.new("int[1]")
    fboId[0] = fbo.id
    gl.glDeleteFramebuffers(1, fboId)

    local texId = ffi.new("int[1]")
    texId[0] = fbo.tex
    gl.glDeleteTextures(1, texId)
end

function cubemapfunctions.bind_fbo(fbo)
    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, fbo.id)
    -- Note: viewport is not set here
end

function cubemapfunctions.unbind_fbo()
    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, 0)
    -- Note: viewport is not set here
end

return cubemapfunctions
