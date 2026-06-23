--[[
2-frontespico — KOReader userpatch that replaces the
"Opening file '<path>'." popup on book open with a centred
author + title splash.

Why a userpatch and not a plugin: plugins are loaded inside
ReaderUI:init — *after* showReaderCoroutine has already shown the
popup for the book KOReader auto-opens at launch ("start with last
file"). Priority-2 userpatches are applied after UIManager is ready
but before that startup open, so this hook covers every code path.

Metadata comes from the book's .sdr sidecar (doc_props), so author and
title appear from the second open onward; on the very first open of a
file the splash falls back to a cleaned-up filename.

Optional: if the KoTheme plugin's settings file exists
(settings/kotheme.lua), its enabled flag also toggles this splash.
Without it the splash is always on.
]]

local ReaderUI      = require("apps/reader/readerui")
local UIManager     = require("ui/uimanager")
local InfoMessage   = require("ui/widget/infomessage")
local DataStorage   = require("datastorage")
local Device        = require("device")
local DocSettings   = require("docsettings")
local Font          = require("ui/font")
local LuaSettings   = require("luasettings")
local Size          = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan  = require("ui/widget/verticalspan")
local ffiutil       = require("ffi/util")
local logger        = require("logger")
local _             = require("gettext")
local Screen        = Device.screen

local kotheme_settings_file = DataStorage:getSettingsDir() .. "/kotheme.lua"

local function splash_enabled()
    local ok, enabled = pcall(function()
        return LuaSettings:open(kotheme_settings_file):nilOrTrue("enabled")
    end)
    if not ok then return true end
    return enabled
end

local function lookup_book_meta(file)
    local props
    pcall(function()
        props = DocSettings:open(file).data.doc_props
    end)
    local title  = props and props.title  or nil
    local author = props and props.authors or nil
    if not title or title == "" then
        local base = ffiutil.basename(file):gsub("%.[^.]+$", "")
        title = base:gsub("_", " "):gsub("%s+", " ")
    end
    if author == "" then author = nil end
    return { title = title, author = author }
end

local function build_splash(file)
    local meta = lookup_book_meta(file)

    local max_w = math.floor(Screen:getWidth() * 0.7)
    if max_w > Screen:scaleBySize(420) then max_w = Screen:scaleBySize(420) end

    local body = VerticalGroup:new{ align = "center" }
    if meta.author then
        table.insert(body, TextBoxWidget:new{
            text      = meta.author,
            face      = Font:getFace("infofont", 18),
            alignment = "center",
            width     = max_w,
        })
        table.insert(body, VerticalSpan:new{ width = Screen:scaleBySize(10) })
    end
    table.insert(body, TextBoxWidget:new{
        text      = meta.title,
        face      = Font:getFace("tfont", 24),
        alignment = "center",
        width     = max_w,
    })

    -- InfoMessage shell: same timeout=0.0 trick as the upstream popup —
    -- the scheduled close only fires once the event loop regains control,
    -- i.e. after the reader has loaded and painted.
    local im = InfoMessage:new{
        text      = " ",
        show_icon = false,
        timeout   = 0.0,
    }
    -- Swap the default icon+text row for our centred body.
    local frame = im.movable and im.movable[1]
    if not frame then return nil end
    frame[1] = body
    frame.padding    = Screen:scaleBySize(14)
    frame.bordersize = Size.border.thin
    return im
end

local _orig = ReaderUI.showReaderCoroutine
ReaderUI.showReaderCoroutine = function(self, file, provider, seamless)
    if seamless or not splash_enabled() then
        return _orig(self, file, provider, seamless)
    end
    local ok, splash = pcall(build_splash, file)
    if not ok or not splash then
        logger.warn("frontespico: falling back to original popup:", splash)
        return _orig(self, file, provider, seamless)
    end
    logger.info("frontespico: showing splash for", file)
    UIManager:show(splash)
    UIManager:forceRePaint()
    UIManager:nextTick(function()
        local co = coroutine.create(function()
            self:doShowReader(file, provider, seamless)
        end)
        local ok_c, err = coroutine.resume(co)
        if err ~= nil or ok_c == false then
            io.stderr:write("[!] doShowReader coroutine crashed:\n")
            io.stderr:write(debug.traceback(co, err, 1))
            Device:setIgnoreInput(false)
            Device.input:inhibitInputUntil(0.2)
            UIManager:show(InfoMessage:new{
                text = _("No reader engine for this file or invalid file.")
            })
            self:showFileManager(file)
        end
    end)
end
