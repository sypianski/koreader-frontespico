--[[
2-frontespico — KOReader userpatch.

Replaces the "Opening file '<path>'." popup on book open with a centred
cover-image splash, falling back to author + title text when the cover
cache misses (first open, or coverbrowser plugin disabled).

Cover lookup uses BookInfoManager (coverbrowser plugin's zstd-cached
thumbnails) — no document open, no decode work in the startup path.

forceRePaint is kept: without it the splash never reaches the
framebuffer before doShowReader overwrites it. The ~hundreds of ms
cost on slow hardware is the price of actually seeing the splash.
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
local ImageWidget   = require("ui/widget/imagewidget")
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

local function lookup_cover_bb(file)
    -- Pull the cached cover from BookInfoManager (coverbrowser plugin).
    -- Returns nil if coverbrowser is missing or the book hasn't been
    -- scanned yet. We never call extractBookInfo synchronously — that
    -- would defeat the speed gain by decoding the EPUB at startup.
    -- BookInfoManager lives inside coverbrowser.koplugin and uses a bare
    -- require("bookinfomanager"). From a userpatch its directory isn't on
    -- package.path, so we splice it in for one dofile.
    local cb_dir = "plugins/coverbrowser.koplugin/"
    local saved_path = package.path
    package.path = cb_dir .. "?.lua;" .. package.path
    local ok, bookinfo = pcall(function()
        local BookInfoManager = dofile(cb_dir .. "bookinfomanager.lua")
        return BookInfoManager:getBookInfo(file, true)
    end)
    package.path = saved_path
    if not ok then logger.warn("frontespico: cover load err:", bookinfo); return nil end
    if not bookinfo then logger.info("frontespico: no bookinfo row for", file); return nil end
    if not bookinfo.has_cover then logger.info("frontespico: bookinfo has_cover=false for", file); return nil end
    logger.info("frontespico: cover_bb loaded, w=", bookinfo.cover_w, "h=", bookinfo.cover_h)
    return bookinfo.cover_bb
end

local function build_text_body(file, max_w)
    local meta = lookup_book_meta(file)
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
    return body
end

local function build_cover_body(cover_bb)
    -- 1:1 — no upscale (blurry pixels), no downscale (loses detail).
    -- Just paint the cached BB at native size, centred.
    local body = VerticalGroup:new{ align = "center" }
    table.insert(body, ImageWidget:new{
        image            = cover_bb,
        scale_factor     = 1,
        image_disposable = false,
    })
    return body
end

local function build_splash(file)
    local text_max_w = math.min(math.floor(Screen:getWidth() * 0.7),
                                Screen:scaleBySize(420))
    local body
    local cover_bb = lookup_cover_bb(file)
    if cover_bb then
        body = build_cover_body(cover_bb)
    else
        body = build_text_body(file, text_max_w)
    end

    local im = InfoMessage:new{
        text      = " ",
        show_icon = false,
        timeout   = 0.0,
    }
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
