--[[ postprocessingslides_scene.lua

    A slideshow containing multiple slides in a single scene. 
]]

postprocessingslides_scene = {}

require("util.slideshow")
local mm = require("util.matrixmath")

local sQuad = require("scene.vsfsquad")
local highlightQuad = require("util.fullscreen_shader")

local slides = {
    Slideshow.new({
        title="Post Processing in GLSL",
        bullets={
        "",
        "",
        "    Jim Susinno",
        "    Khronos Boston Chapter",
        },
        shown_lines = 4,
    }),

    Slideshow.new({
        title="Motivation",
        bullets={
            "Make things look interesting",
        }
    }),

    Slideshow.new({
        title="Implementation",
        bullets={
            "- Render to buffer",
            "- Present buffer to screen",
        }
    }),

    Slideshow.new({
        title="Using FBOs",
        bullets={
            "- Bind to render target",
            "- All subsequent draws go to it",
            "- Unbind (bind FBO 0)",
            "- Bind RT as texture and render",
        },
    }),

    Slideshow.new({
        title="Using FBOs",
        bullets={
            "In OpenGL:",
        },
        codesnippet = {
            "glBindFramebuffer(GL_FRAMEBUFFER, id);",
            "// ...draw into FBO",
            "glBindFramebuffer(GL_FRAMEBUFFER, 0);",
            "// draw to screen",
        }
    }),

    Slideshow.new({
        title='The trivial "filter"',
        bullets={
            "- Simply passes texture data through",
            "- Standard input variables",
        },
        codesnippet = {
            "uniform sampler2D tex;",
            "in vec2 uv;",
            "out vec4 fragColor;",
            "void main()",
            "{",
            "    fragColor = texture(tex, uv);",
            "}",
        }
    }),

    Slideshow.new({
        title="Color Inversion",
        bullets={
            "- Shows the inverse of each pixel",
        },
        codesnippet = {
            "void main()",
            "{",
            "    fragColor = vec4(1.) - texture(tex, uv);",
            "}",
        }
    }),
}

local highlight_fragsrc = [[
void main()
{
    if (uv.x < .1) discard;
    if (uv.y < .26) discard;
    if (uv.x > .5) discard;
    if (uv.y > .4) discard;
    fragColor = vec4(1.,.5,.5,1.);
}
]]

local slide_idx = 1
local slide = slides[1]

local dataDir = nil

-- Since data files must be loaded from disk, we have to know
-- where to find them. Set the directory with this standard entry point.
function postprocessingslides_scene.setDataDirectory(dir)
    dataDir = dir
end

function postprocessingslides_scene.initGL()
    slide:initGL(dataDir)

    sQuad.initGL()
    highlightQuad = FullscreenShader.new(highlight_fragsrc)
    highlightQuad:initGL()

    local dir = "fonts"
    local fontname = "courier_512"
    if dataDir then dir = dataDir .. "/" .. dir end
    codefont = GLFont.new(fontname..'.fnt', fontname..'_0.raw')
    codefont:setDataDirectory(dir)
    codefont:initGL()
end

function postprocessingslides_scene.exitGL()
    slide:exitGL()
    sQuad.exitGL()
    highlightQuad:exitGL()

    codefont:exitGL()
end

-- Some slides may contain some live graphics in addition to text.
-- Nothing but special cases in this function.
-- TODO: move these into their respective slide table
function postprocessingslides_scene.draw_ancillary_scenes(view, proj)
    if slide_idx == 3 then
        if slide.shown_lines > 1 then
            sQuad.render_for_one_eye(view, proj)
        end
    end

    -- A highlight over a code snippet
    -- Rectangle is defined in the pure frag shader source.
    if slide_idx == 6 then
        if slide.shown_lines > 1 then
            gl.glDepthMask(GL.GL_FALSE)
            highlightQuad:render(view, proj, nil)
            gl.glDepthMask(GL.GL_TRUE)
        end
    end
end

-- Draw slide number in the lower left of the window
function postprocessingslides_scene.draw_slide_number()
    local w,h = 2160/2,1440/2 -- guess a resolution
    local m = {}
    mm.make_identity_matrix(m)
    mm.glh_translate(m, 10,h-30,0)
    local s = .2
    mm.glh_scale(m,s,s,s)
    local p = {}
    mm.make_identity_matrix(p)
    mm.glh_ortho(p, 0, w, h, 0, -1, 1)
    local txt = tostring(slide_idx).."/"..tostring(#slides)
    slide.glfont:render_string(m, p, {.8,.8,.8}, txt)
end

function postprocessingslides_scene.draw_code_snippet(lines)
    if not codefont then return end
    if not lines then return end

    local m = {}
    mm.make_identity_matrix(m)
    mm.glh_translate(m, 120, 440, 0)
    local s = .3
    mm.glh_scale(m,s,s,s)
    local p = {}
    local w,h = 2160/2,1440/2 -- guess a resolution
    mm.glh_ortho(p, 0, w, h, 0, -1, 1)
    local col = {0,0,0}
    for _,line in pairs(lines) do
        codefont:render_string(m, p, col, line)
        mm.glh_translate(m, 0, 100, 0)
    end
end

function postprocessingslides_scene.render_for_one_eye(view, proj)
    gl.glClearColor(1,1,1,0)
    gl.glClear(GL.GL_COLOR_BUFFER_BIT + GL.GL_DEPTH_BUFFER_BIT)

    postprocessingslides_scene.draw_ancillary_scenes(view, proj)
    slide:draw_text()

    local lines = slide.codesnippet
    postprocessingslides_scene.draw_code_snippet(lines)

    postprocessingslides_scene.draw_slide_number()
end

function postprocessingslides_scene.timestep(absTime, dt)
end

function postprocessingslides_scene.increment_scene(incr)
    slide_idx = slide_idx + incr

    if slide_idx < 1 then slide_idx = 1 end
    if slide_idx > #slides then slide_idx = #slides end

    slide:exitGL()
    slide = slides[slide_idx]
    slide:initGL(dataDir)
end

function postprocessingslides_scene.keypressed(ch)
    if ch == 257 --[[glfw.GLFW.KEY_ENTER]] then
        postprocessingslides_scene.increment_scene(1)
        return true
    end

    if ch == 259 --[[glfw.GLFW.KEY_BACKSPACE]] then
        postprocessingslides_scene.increment_scene(-1)
        return true
    end

    if ch == 262 then -- right arrow in glfw
        if slide.shown_lines >= #slide.bullet_points then
            postprocessingslides_scene.increment_scene(1)
            return true
        end
    end

    if ch == 263 then -- left arrow in glfw
        if slide.shown_lines <= 0 then
            postprocessingslides_scene.increment_scene(-1)
            return true
        end
    end

    return slide:keypressed(ch)
end

local action_types = {
  [0] = "Down",
  [1] = "Up",
  [2] = "Move",
  [3] = "Cancel",
  [4] = "Outside",
  [5] = "PointerDown",
  [6] = "PointerUp",
}

function postprocessingslides_scene.onSingleTouch(pointerid, action, x, y)
    local actionflag = action % 255
    local a = action_types[actionflag]
    if a == "Down" or a == "PointerDown" then
        postprocessingslides_scene.keypressed(262)
    end
end

return postprocessingslides_scene
