-- fbofunctions.lua
fbofunctions = {}

local openGL = require("opengl")
local ffi = require("ffi")

function fbofunctions.allocate_fbo(w, h, use_depth)
    fbo = {}
    fbo.w = w
    fbo.h = h

    local fboId = ffi.new("GLuint[1]")
    gl.glGenFramebuffers(1, fboId)
    fbo.id = fboId[0]
    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, fbo.id)

    if use_depth then
        local dtxId = ffi.new("GLuint[1]")
        gl.glGenTextures(1, dtxId)
        fbo.depth = dtxId[0]
        gl.glBindTexture(GL.GL_TEXTURE_2D, fbo.depth)
        gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_CLAMP_TO_EDGE)
        gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_CLAMP_TO_EDGE)
        gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR)
        gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR)
        --gl.glTexParameteri( GL.GL_TEXTURE_2D, GL.GL_DEPTH_TEXTURE_MODE, GL.GL_INTENSITY ); --deprecated, out in 3.1
        gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAX_LEVEL, 0)
        gl.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_DEPTH_COMPONENT,
                      w, h, 0,
                      GL.GL_DEPTH_COMPONENT, GL.GL_UNSIGNED_BYTE, nil)
        gl.glBindTexture(GL.GL_TEXTURE_2D, 0)
        gl.glFramebufferTexture2D(GL.GL_FRAMEBUFFER, GL.GL_DEPTH_ATTACHMENT, GL.GL_TEXTURE_2D, fbo.depth, 0)
    end

    local texId = ffi.new("GLuint[1]")
    gl.glGenTextures(1, texId)
    fbo.tex = texId[0]
    gl.glBindTexture(GL.GL_TEXTURE_2D, fbo.tex)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAX_LEVEL, 0)
    gl.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_RGBA8,
                  w, h, 0,
                  GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, nil)
    gl.glBindTexture(GL.GL_TEXTURE_2D, 0)
    gl.glFramebufferTexture2D(GL.GL_FRAMEBUFFER, GL.GL_COLOR_ATTACHMENT0, GL.GL_TEXTURE_2D, fbo.tex, 0)

    local status = gl.glCheckFramebufferStatus(GL.GL_FRAMEBUFFER)
    if status ~= GL.GL_FRAMEBUFFER_COMPLETE then
        print("ERROR: Framebuffer status: "..status)
    end

    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, 0)
    return fbo
end

function fbofunctions.deallocate_fbo(fbo)
    if fbo == nil then return end
    local fboId = ffi.new("int[1]")
    fboId[0] = fbo.id
    gl.glDeleteFramebuffers(1, fboId)

    local texId = ffi.new("int[1]")
    texId[0] = fbo.tex
    gl.glDeleteTextures(1, texId)

    if fbo.depth then
        local depthId = ffi.new("int[1]")
        depthId[0] = fbo.depth
        gl.glDeleteTextures(1, depthId)
    end
end

function fbofunctions.bind_fbo(fbo)
    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, fbo.id)
    -- Note: viewport is not set here
end

function fbofunctions.unbind_fbo()
    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, 0)
    -- Note: viewport is not set here
end

return fbofunctions
