-- ══════════════════════════════════════════════
--   SHADE GUI LIBRARY  |  Photon API
-- ══════════════════════════════════════════════
-- Extracted from SHADE. Reusable framework.
--
--   local gui = loadstring(...)()
--   local S = { aim_enabled = false, fov = 90 }
--   gui.init(S, { toggle_key = 0xA4, title = "SHADE", subtitle = "My Script" })
--
--   gui.add_tab("Combat", function(x, y)
--       y = gui.section(x, y, "Aimbot")
--       y = gui.toggle(x, y, "Enabled", "aim_enabled")
--       y = gui.slider(x, y, "FOV Size", "fov", 30, 180)
--       if gui.button(x, y, 200, 24, "Reset FOV") then S.fov = 90 end
--       y = y + 30
--       return y
--   end)
-- ══════════════════════════════════════════════

local SHADE_GUI = {}

-- User settings table (you pass this in init)
local S = {}

-- ══════════════════════════════════════════════
--   UTILITIES
-- ══════════════════════════════════════════════

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- ══════════════════════════════════════════════
--   GUI STATE
-- ══════════════════════════════════════════════

local GUI = {
    visible   = true,
    x         = 40,
    y         = 40,
    w         = 290,
    dragging  = false,
    drag_ox   = 0,
    drag_oy   = 0,
    tab       = 1,
    scroll    = 0,
    sb_drag   = false,
    sb_drag_oy= 0,
    mx        = 0,
    my        = 0,
    mb_down   = false,
    mb_prev   = false,
    title     = "SHADE",
    subtitle  = "GUI Library",
}

local T = {
    bg        = color(.08,.08,.10, 0.97),
    border    = color(.22,.22,.28, 1),
    title_bg  = color(.10,.10,.13, 1),
    accent    = color(.38,.18,.85, 1),
    accent2   = color(.52,.28,.98, 1),
    tab_bg    = color(.13,.13,.17, 1),
    tab_sel   = color(.20,.10,.45, 1),
    text      = color(.92,.92,.96, 1),
    text_dim  = color(.55,.55,.62, 1),
    tog_on    = color(.38,.18,.85, 1),
    tog_off   = color(.25,.25,.30, 1),
    slider_bg = color(.18,.18,.22, 1),
    btn_bg    = color(.18,.10,.35, 1),
    btn_hov   = color(.28,.14,.52, 1),
    sep       = color(.20,.20,.26, 1),
}

-- ══════════════════════════════════════════════
--   KEYBIND CONFIG
-- ══════════════════════════════════════════════

local GUI_BIND = {
    vk        = 0xA4,
    listening = false,
}

local VK_LMB = 0x01

local VK_NAMES = {
    [0xA4]="Left Alt",  [0xA5]="Right Alt",
    [0xA2]="Left Ctrl", [0xA3]="Right Ctrl",
    [0xA0]="Left Shift",[0xA1]="Right Shift",
    [0x2D]="Insert",    [0x24]="Home",
    [0x23]="End",       [0x21]="PgUp",
    [0x22]="PgDn",      [0x2E]="Delete",
    [0x70]="F1",  [0x71]="F2",  [0x72]="F3",  [0x73]="F4",
    [0x74]="F5",  [0x75]="F6",  [0x76]="F7",  [0x77]="F8",
    [0x78]="F9",  [0x79]="F10", [0x7A]="F11", [0x7B]="F12",
}

local VK_SCAN = {
    0xA4,0xA5,0xA2,0xA3,0xA0,0xA1,
    0x2D,0x24,0x23,0x21,0x22,0x2E,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B,
}

local function vk_name(vk)
    return VK_NAMES[vk] or string.format("0x%02X", vk)
end

-- ══════════════════════════════════════════════
--   CONSTANTS
-- ══════════════════════════════════════════════

local TITLE_H   = 28
local TAB_H     = 26
local CONTENT_H = 500
local ROW_H     = 22
local PAD       = 10
local TOGGLE_W  = 28
local TOGGLE_H  = 14

-- clip bounds updated each frame in draw_gui
local CLIP_Y0 = 0
local CLIP_Y1 = 9999

-- ══════════════════════════════════════════════
--   INPUT HELPERS
-- ══════════════════════════════════════════════

local function hover(x, y, w, h)
    return GUI.mx >= x and GUI.mx <= x+w and GUI.my >= y and GUI.my <= y+h
end

-- FIX: clicks fire on mouse-up (prev=down, cur=up)
local function clicked(x, y, w, h)
    return GUI.mb_prev and not GUI.mb_down and hover(x, y, w, h)
end

local function pressed(x, y, w, h)
    return GUI.mb_down and not GUI.mb_prev and hover(x, y, w, h)
end

-- FIX: in_content() guard prevents title/tab clicks bleeding to widgets
local function in_content()
    return hover(GUI.x, CLIP_Y0, GUI.w, CONTENT_H)
end

-- FIX: visible() skips drawing rows outside the clip region
local function visible(y)
    return y + ROW_H > CLIP_Y0 and y < CLIP_Y1
end

-- ══════════════════════════════════════════════
--   WIDGETS
-- ══════════════════════════════════════════════

local function draw_toggle(x, y, label, value)
    if visible(y) then
        local ty = y + (ROW_H - TOGGLE_H) * .5
        local tc = value and T.tog_on or T.tog_off
        render.add_rect_filled(vector2(x,ty), vector2(x+TOGGLE_W,ty+TOGGLE_H), tc, 7)
        local tx = value and (x + TOGGLE_W - TOGGLE_H + 2) or (x + 2)
        render.add_circle_filled(vector2(tx + (TOGGLE_H-4)*.5, ty + TOGGLE_H*.5),
                                 (TOGGLE_H-4)*.5, color(1,1,1,.95))
        render.add_text(vector2(x + TOGGLE_W + 7, y + (ROW_H-13)*.5), label, T.text, nil, false)
    end
    return y + ROW_H
end

local function draw_toggle_widget(x, y, label, key)
    if in_content() and clicked(x, y, GUI.w - PAD*2, ROW_H) then
        S[key] = not S[key]
    end
    return draw_toggle(x, y, label, S[key])
end

local function draw_sub_toggle(x, y, label, key, parent_key)
    if not S[parent_key] then return y end
    local ix = x + 16
    local iw = GUI.w - PAD*2 - 16
    if visible(y) then
        render.add_line(vector2(x+8, y+4), vector2(x+8, y+ROW_H-4), T.sep, 1)
    end
    if in_content() and clicked(ix, y, iw, ROW_H) then
        S[key] = not S[key]
    end
    return draw_toggle(ix, y, label, S[key])
end

local function draw_button(x, y, w, h, label)
    if visible(y) then
        local hov = hover(x, y, w, h)
        local bg  = hov and T.btn_hov or T.btn_bg
        render.add_rect_filled(vector2(x,y), vector2(x+w,y+h), bg, 5)
        render.add_rect(vector2(x,y), vector2(x+w,y+h), T.accent, 5, 1)
        local sz = render.get_text_size(label)
        render.add_text(vector2(x+w*.5-sz.x*.5, y+h*.5-sz.y*.5), label, T.text, nil, false)
    end
    return in_content() and clicked(x, y, w, h)
end

local function draw_slider(x, y, label, key, lo, hi)
    local val = S[key]
    local bw  = GUI.w - PAD*2
    local sh  = 4
    local sy  = y + ROW_H - sh - 4
    if visible(y) then
        render.add_text(vector2(x, y+2), label, T.text_dim, nil, false)
        local vstr = tostring(math.floor(val))
        local vsz  = render.get_text_size(vstr)
        render.add_text(vector2(x + bw - vsz.x, y+2), vstr, T.text, nil, false)
        render.add_rect_filled(vector2(x,sy), vector2(x+bw,sy+sh), T.slider_bg, 2)
        local frac = (val - lo) / (hi - lo)
        render.add_rect_filled(vector2(x,sy), vector2(x+frac*bw,sy+sh), T.accent2, 2)
        render.add_circle_filled(vector2(x+frac*bw, sy+sh*.5), 6, T.accent2)
    end
    if in_content() and GUI.mb_down and hover(x, sy-6, bw, sh+12) then
        local nf = clamp01((GUI.mx - x) / bw)
        S[key] = math.floor(lo + nf*(hi-lo) + .5)
    end
    return y + ROW_H + 10
end

local function draw_section(x, y, label)
    if visible(y) then
        render.add_text(vector2(x, y), label, T.accent2, nil, false)
        local sz = render.get_text_size(label)
        render.add_line(vector2(x+sz.x+6, y+sz.y*.5),
                        vector2(x + GUI.w - PAD*2, y+sz.y*.5), T.sep, 1)
    end
    return y + 19
end

local function draw_color_swatch(x, y, label, ct)
    if visible(y) then
        render.add_text(vector2(x, y+(ROW_H-13)*.5), label, T.text_dim, nil, false)
        local sw  = 50
        local sh2 = 14
        local sx  = x + GUI.w - PAD*2 - sw
        local sy2 = y + (ROW_H-sh2)*.5
        render.add_rect_filled(vector2(sx,sy2), vector2(sx+sw,sy2+sh2),
                                color(ct.r, ct.g, ct.b, 1), 3)
        render.add_rect(vector2(sx,sy2), vector2(sx+sw,sy2+sh2), T.border, 3, 1)
    end
    return y + ROW_H
end

-- ══════════════════════════════════════════════
--   TAB SYSTEM
-- ══════════════════════════════════════════════

local tabs            = {}
local tab_est_heights = {}
local TAB_LABELS      = {}
local TAB_FNS         = {}

function SHADE_GUI.add_tab(name, draw_fn)
    table.insert(tabs, { name = name, fn = draw_fn })
    table.insert(TAB_LABELS, name)
    table.insert(TAB_FNS, draw_fn)
    tab_est_heights[#tabs] = 300
end

-- ══════════════════════════════════════════════
--   MAIN DRAW
-- ══════════════════════════════════════════════

local function draw_gui()
    if not GUI.visible then return end

    local gx, gy, gw = GUI.x, GUI.y, GUI.w
    local tab_count  = #TAB_LABELS
    if tab_count == 0 then return end

    local tab_w      = math.floor(gw / tab_count)
    local win_h      = TITLE_H + TAB_H + CONTENT_H

    -- window background
    render.add_rect_filled(vector2(gx,gy), vector2(gx+gw,gy+win_h), T.bg, 8)
    render.add_rect(vector2(gx,gy), vector2(gx+gw,gy+win_h), T.border, 8, 1)

    -- title bar
    render.add_rect_filled(vector2(gx,gy), vector2(gx+gw,gy+TITLE_H), T.title_bg, 8)
    render.add_line(vector2(gx,gy+TITLE_H), vector2(gx+gw,gy+TITLE_H), T.border, 1)
    render.add_rect_filled(vector2(gx,gy), vector2(gx+3,gy+TITLE_H), T.accent, 0)
    render.add_text(vector2(gx+12, gy+(TITLE_H-13)*.5), GUI.title, T.accent2, nil, false)
    local sub    = GUI.subtitle
    local sub_sz = render.get_text_size(sub)
    render.add_text(vector2(gx+gw-sub_sz.x-PAD, gy+(TITLE_H-13)*.5), sub, T.text_dim, nil, false)

    -- drag (title bar only)
    if pressed(gx, gy, gw, TITLE_H) then
        GUI.dragging = true
        GUI.drag_ox  = GUI.mx - gx
        GUI.drag_oy  = GUI.my - gy
    end
    if not GUI.mb_down then GUI.dragging = false end
    if GUI.dragging then
        GUI.x = GUI.mx - GUI.drag_ox
        GUI.y = GUI.my - GUI.drag_oy
    end

    -- tab bar
    local tby = gy + TITLE_H
    render.add_rect_filled(vector2(gx,tby), vector2(gx+gw,tby+TAB_H), T.tab_bg, 0)
    render.add_line(vector2(gx,tby+TAB_H), vector2(gx+gw,tby+TAB_H), T.border, 1)

    for i, lbl in ipairs(TAB_LABELS) do
        local tx    = gx + (i-1)*tab_w
        local tw    = (i == tab_count) and (gw-(tab_count-1)*tab_w) or tab_w
        local issel = (GUI.tab == i)
        if issel then
            render.add_rect_filled(vector2(tx,tby), vector2(tx+tw,tby+TAB_H), T.tab_sel, 0)
            render.add_rect_filled(vector2(tx,tby+TAB_H-2), vector2(tx+tw,tby+TAB_H), T.accent, 0)
        end
        local lsz = render.get_text_size(lbl)
        render.add_text(vector2(tx+tw*.5-lsz.x*.5, tby+(TAB_H-13)*.5),
                        lbl, issel and T.text or T.text_dim, nil, false)
        if clicked(tx, tby, tw, TAB_H) then
            GUI.tab    = i
            GUI.scroll = 0
        end
        if i < tab_count then
            render.add_line(vector2(tx+tw,tby+4), vector2(tx+tw,tby+TAB_H-4), T.border, 1)
        end
    end

    -- content area
    local cx0     = gx + PAD
    local cy0     = gy + TITLE_H + TAB_H
    local cy1     = cy0 + CONTENT_H

    -- clamp scroll
    local est_h      = tab_est_heights[GUI.tab] or 300
    local scroll_max = math.max(0, est_h - CONTENT_H)
    GUI.scroll       = clamp(GUI.scroll, 0, scroll_max)

    CLIP_Y0 = cy0
    CLIP_Y1 = cy1

    -- draw tab content
    local content_start_y = cy0 + PAD - GUI.scroll
    local ok_frame, final_y = pcall(TAB_FNS[GUI.tab], cx0, content_start_y)
    if ok_frame and final_y then
        tab_est_heights[GUI.tab] = final_y - content_start_y + PAD
    end

    -- FIX: redraw title bar + tab bar on top to cover any content bleed-through
    render.add_rect_filled(vector2(gx,gy), vector2(gx+gw,cy0), T.bg, 8)
    render.add_rect_filled(vector2(gx,gy), vector2(gx+gw,gy+TITLE_H), T.title_bg, 0)
    render.add_rect_filled(vector2(gx,gy), vector2(gx+3,gy+TITLE_H), T.accent, 0)
    render.add_text(vector2(gx+12, gy+(TITLE_H-13)*.5), GUI.title, T.accent2, nil, false)
    render.add_text(vector2(gx+gw-sub_sz.x-PAD, gy+(TITLE_H-13)*.5), sub, T.text_dim, nil, false)
    render.add_line(vector2(gx,gy+TITLE_H), vector2(gx+gw,gy+TITLE_H), T.border, 1)
    render.add_rect_filled(vector2(gx,tby), vector2(gx+gw,tby+TAB_H), T.tab_bg, 0)
    for i, lbl in ipairs(TAB_LABELS) do
        local tx    = gx + (i-1)*tab_w
        local tw    = (i == tab_count) and (gw-(tab_count-1)*tab_w) or tab_w
        local issel = (GUI.tab == i)
        if issel then
            render.add_rect_filled(vector2(tx,tby), vector2(tx+tw,tby+TAB_H), T.tab_sel, 0)
            render.add_rect_filled(vector2(tx,tby+TAB_H-2), vector2(tx+tw,tby+TAB_H), T.accent, 0)
        end
        local lsz = render.get_text_size(lbl)
        render.add_text(vector2(tx+tw*.5-lsz.x*.5, tby+(TAB_H-13)*.5),
                        lbl, issel and T.text or T.text_dim, nil, false)
        if i < tab_count then
            render.add_line(vector2(tx+tw,tby+4), vector2(tx+tw,tby+TAB_H-4), T.border, 1)
        end
    end
    render.add_line(vector2(gx,tby+TAB_H), vector2(gx+gw,tby+TAB_H), T.border, 1)

    -- mask anything below the content area
    render.add_rect_filled(vector2(gx,cy1), vector2(gx+gw,cy1+60), T.bg, 0)
    -- outer border last
    render.add_rect(vector2(gx,gy), vector2(gx+gw,gy+win_h), T.border, 8, 1)

    -- scrollbar
    if scroll_max > 0 then
        local sb_x    = gx + gw - 6
        local sb_w    = 4
        local sb_y0   = cy0 + 2
        local sb_h    = CONTENT_H - 4
        local tfrac   = clamp01(CONTENT_H / est_h)
        local th      = math.max(math.floor(sb_h * tfrac), 24)
        local thumb_y = sb_y0 + math.floor((GUI.scroll / scroll_max) * (sb_h - th))

        render.add_rect_filled(vector2(sb_x,sb_y0), vector2(sb_x+sb_w,sb_y0+sb_h), T.sep, 2)

        if pressed(sb_x-4, sb_y0, sb_w+8, sb_h) then
            GUI.sb_drag    = true
            GUI.sb_drag_oy = GUI.my - thumb_y
        end
        if not GUI.mb_down then GUI.sb_drag = false end
        if GUI.sb_drag then
            local frac = clamp01((GUI.my - GUI.sb_drag_oy - sb_y0) / (sb_h - th))
            GUI.scroll = math.floor(frac * scroll_max + .5)
        end

        render.add_rect_filled(vector2(sb_x,thumb_y), vector2(sb_x+sb_w,thumb_y+th), T.accent, 2)
    end
end

-- ══════════════════════════════════════════════
--   PUBLIC API
-- ══════════════════════════════════════════════

function SHADE_GUI.init(settings_tbl, opts)
    S = settings_tbl or {}
    opts = opts or {}

    if opts.toggle_key  then GUI_BIND.vk = opts.toggle_key end
    if opts.title       then GUI.title = opts.title end
    if opts.subtitle    then GUI.subtitle = opts.subtitle end
    if opts.x           then GUI.x = opts.x end
    if opts.y           then GUI.y = opts.y end
    if opts.width       then GUI.w = opts.width end

    hook.add("render", "shade_gui_lib", function()
        -- FIX: 0x01 = left mouse button VK code
        local mp    = input.get_mouse_position()
        GUI.mx      = mp.x
        GUI.my      = mp.y
        GUI.mb_prev = GUI.mb_down
        GUI.mb_down = input.key_down(VK_LMB)

        draw_gui()
    end)

    hook.addkey(GUI_BIND.vk, "shade_gui_toggle", function(tog)
        if tog then GUI.visible = not GUI.visible end
    end)
end

function SHADE_GUI.unload()
    pcall(function() hook.remove("render", "shade_gui_lib") end)
    pcall(function() hook.removekey(GUI_BIND.vk, "shade_gui_toggle") end)
end

function SHADE_GUI.set_visible(v) GUI.visible = v end
function SHADE_GUI.is_visible() return GUI.visible end

-- Expose theme if you want to edit colors
SHADE_GUI.theme = T

-- ══════════════════════════════════════════════
--   EXPOSED WIDGETS
-- ══════════════════════════════════════════════

SHADE_GUI.toggle       = draw_toggle_widget
SHADE_GUI.sub_toggle   = draw_sub_toggle
SHADE_GUI.slider       = draw_slider
SHADE_GUI.button       = draw_button
SHADE_GUI.section      = draw_section
SHADE_GUI.color_swatch = draw_color_swatch

SHADE_GUI.label = function(x, y, text, col)
    if visible(y) then
        render.add_text(vector2(x, y+2), text, col or T.text_dim, nil, false)
    end
    return y + ROW_H
end

-- Keybind picker widget (generic, no hook manipulation)
SHADE_GUI.keybind = function(x, y, label, bind_tbl, on_change)
    if visible(y) then
        local bind_lbl = bind_tbl.listening and "Press any key..." or (label .. ": " .. vk_name(bind_tbl.vk))
        local bind_col = bind_tbl.listening and T.accent2 or T.text
        render.add_text(vector2(x, y+(ROW_H-13)*.5), bind_lbl, bind_col, nil, false)
        local bw2 = 60
        local bx2 = x + GUI.w - PAD*2 - bw2
        local bbg = bind_tbl.listening and color(.5,.1,.1,1) or (hover(bx2,y,bw2,ROW_H) and T.btn_hov or T.btn_bg)
        render.add_rect_filled(vector2(bx2,y+2), vector2(bx2+bw2,y+ROW_H-2), bbg, 4)
        render.add_rect(vector2(bx2,y+2), vector2(bx2+bw2,y+ROW_H-2), T.accent, 4, 1)
        local blbl = bind_tbl.listening and "Cancel" or "Change"
        local bsz  = render.get_text_size(blbl)
        render.add_text(vector2(bx2+bw2*.5-bsz.x*.5, y+(ROW_H-bsz.y)*.5), blbl, T.text, nil, false)
    end
    local bw3 = 60
    local bx3 = x + GUI.w - PAD*2 - bw3
    if in_content() and clicked(bx3, y, bw3, ROW_H) then
        bind_tbl.listening = not bind_tbl.listening
    end
    if bind_tbl.listening then
        for _, vk in ipairs(VK_SCAN) do
            if input.key_down(vk) then
                bind_tbl.vk = vk
                bind_tbl.listening = false
                if on_change then pcall(on_change, vk) end
                log.notification(label .. " set to " .. vk_name(vk), "success")
                break
            end
        end
    end
    return y + ROW_H + 4
end

return SHADE_GUI
