-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: the shared look catalog (BIT.Looks): fill textures, colours, and the pickers for both.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- Every module that draws a bar fill or an outline (DoTInfo, CastPrediction, ...) reads its choices from here, so a new
-- texture or colour shows up in all of them at once:
--
--   BIT.Looks.Textures()            the texture catalog, a list of { id, label, path, tiled, gradient, group }:
--                                    flat/gradient, Blizzard's own bar textures, the addon's patterns and soft
--                                    shadings (Core/Textures/Fill, made by tools/make_fill_textures.py) and, when
--                                    LibSharedMedia-3.0 is loaded (ElvUI, Details, ...), every "statusbar" it knows
--   BIT.Looks.Texture(id)           one catalog entry (any saved id; an unknown id answers the flat texture)
--   BIT.Looks.Merge(list)           appends the catalog entries a module's own list does not have yet
--   BIT.Looks.Palette               the named colours, { id, label, rgb }; a colour id is a name or "#rrggbb"
--   BIT.Looks.Rgb(id)               { r, g, b } for a name or a hex id, nil for anything else
--   BIT.Looks.PickColor(id, set)    opens Blizzard's colour picker; set("#rrggbb") runs while the user drags
--   BIT.Looks.ColorList(extra)      the palette as a menu list, with "Custom colour..." last (extra entries first)
--   BIT.Looks.PickList(owner, list, current, pick)  one drop-down for every menu: scrolls, shows a swatch or a
--                                    preview of each texture, and groups entries under header rows
--
-- Nothing here reads gameplay data or saved settings; a module stores only the id (a string) it picked.

local ADDON, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local Looks = {}
BIT.Looks = Looks

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FILL_DIR = "Interface\\AddOns\\" .. (ADDON or "Ready2QuestCombat") .. "\\Core\\Textures\\Fill\\"
local DOT_DIR = "Interface\\AddOns\\" .. (ADDON or "Ready2QuestCombat") .. "\\Modules\\DoTInfo\\Textures\\"

---------------------------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------------------------

-- The first nine are DoTInfo's and CastPrediction's original presets (saved settings name them), the rest are new.
Looks.Palette = {
    { id = "purple", label = "Purple", rgb = { 0.7, 0.3, 1 } },
    { id = "gold",   label = "Gold",   rgb = { 1, 0.85, 0.1 } },
    { id = "white",  label = "White",  rgb = { 1, 1, 1 } },
    { id = "red",    label = "Red",    rgb = { 1, 0.2, 0.2 } },
    { id = "orange", label = "Orange", rgb = { 1, 0.55, 0.1 } },
    { id = "green",  label = "Green",  rgb = { 0.3, 1, 0.3 } },
    { id = "cyan",   label = "Cyan",   rgb = { 0.2, 0.9, 1 } },
    { id = "pink",   label = "Pink",   rgb = { 1, 0.45, 0.6 } },
    { id = "black",  label = "Black",  rgb = { 0, 0, 0 } },
    { id = "crimson",  label = "Crimson",   rgb = { 0.78, 0.08, 0.2 } },
    { id = "maroon",   label = "Maroon",    rgb = { 0.5, 0.05, 0.1 } },
    { id = "coral",    label = "Coral",     rgb = { 1, 0.45, 0.35 } },
    { id = "amber",    label = "Amber",     rgb = { 1, 0.7, 0.1 } },
    { id = "yellow",   label = "Yellow",    rgb = { 1, 0.95, 0.2 } },
    { id = "lime",     label = "Lime",      rgb = { 0.65, 1, 0.2 } },
    { id = "forest",   label = "Forest",    rgb = { 0.1, 0.45, 0.15 } },
    { id = "mint",     label = "Mint",      rgb = { 0.5, 1, 0.75 } },
    { id = "teal",     label = "Teal",      rgb = { 0.1, 0.75, 0.7 } },
    { id = "sky",      label = "Sky blue",  rgb = { 0.45, 0.78, 1 } },
    { id = "blue",     label = "Blue",      rgb = { 0.25, 0.5, 1 } },
    { id = "navy",     label = "Navy",      rgb = { 0.08, 0.15, 0.4 } },
    { id = "indigo",   label = "Indigo",    rgb = { 0.3, 0.2, 0.75 } },
    { id = "violet",   label = "Violet",    rgb = { 0.55, 0.35, 1 } },
    { id = "magenta",  label = "Magenta",   rgb = { 1, 0.2, 0.8 } },
    { id = "lavender", label = "Lavender",  rgb = { 0.8, 0.7, 1 } },
    { id = "peach",    label = "Peach",     rgb = { 1, 0.75, 0.6 } },
    { id = "bone",     label = "Bone",      rgb = { 0.93, 0.9, 0.78 } },
    { id = "brown",    label = "Brown",     rgb = { 0.55, 0.35, 0.15 } },
    { id = "olive",    label = "Olive",     rgb = { 0.55, 0.55, 0.1 } },
    { id = "ice",      label = "Ice",       rgb = { 0.7, 0.95, 1 } },
    { id = "silver",   label = "Silver",    rgb = { 0.8, 0.82, 0.86 } },
    { id = "gray",     label = "Gray",      rgb = { 0.55, 0.55, 0.58 } },
    { id = "charcoal", label = "Charcoal",  rgb = { 0.2, 0.2, 0.22 } },
}
local BY_ID = {}
for _, entry in ipairs(Looks.Palette) do BY_ID[entry.id] = entry.rgb end

local function byte(value)
    value = tonumber(value) or 0
    if value < 0 then value = 0 elseif value > 1 then value = 1 end
    return math.floor(value * 255 + 0.5)
end

function Looks.Hex(r, g, b)
    return string.format("#%02x%02x%02x", byte(r), byte(g), byte(b))
end

function Looks.IsHex(id)
    return type(id) == "string" and id:match("^#%x%x%x%x%x%x$") ~= nil
end

-- { r, g, b } (0..1) of a palette name or a "#rrggbb" id; nil for anything else (including "school").
function Looks.Rgb(id)
    if type(id) ~= "string" then return nil end
    local named = BY_ID[id]
    if named then return named end
    local r, g, b = id:match("^#(%x%x)(%x%x)(%x%x)$")
    if r then return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 } end
    return nil
end

-- The palette as a menu list: `extra` entries (a module's "Spell school") first, "Custom colour..." last. A new
-- table every call, so a module can add its own rows without touching the shared palette.
function Looks.ColorList(extra)
    local list = { kind = "color" }
    for _, entry in ipairs(extra or {}) do list[#list + 1] = entry end
    for _, entry in ipairs(Looks.Palette) do list[#list + 1] = entry end
    list[#list + 1] = { id = "custom", label = "Custom color...", custom = true }
    return list
end

-- The menu entry that stands for a saved colour id (a "#rrggbb" id is not in any list).
function Looks.ColorEntry(list, id)
    for _, entry in ipairs(list) do
        if entry.id == id then return entry end
    end
    local rgb = Looks.Rgb(id)
    if rgb then return { id = id, label = string.format(BIT.L("Custom %s"), id), literal = true, rgb = rgb } end
    return nil
end

-- Blizzard's own colour picker. set("#rrggbb") runs while the user drags; Cancel sets the id the row had before (a name
-- stays a name, "school" stays "school").
function Looks.PickColor(currentId, set)
    local picker = ColorPickerFrame
    if type(picker) ~= "table" or type(set) ~= "function" then return false end
    local rgb = Looks.Rgb(currentId) or { 1, 1, 1 }
    pcall(picker.SetFrameStrata, picker, "FULLSCREEN_DIALOG")
    if type(picker.SetupColorPickerAndShow) == "function" then
        local starting = true
        local function changed()
            if starting then return end
            local r, g, b = picker:GetColorRGB()
            set(Looks.Hex(r, g, b))
        end
        picker:SetupColorPickerAndShow({
            r = rgb[1], g = rgb[2], b = rgb[3], hasOpacity = false,
            swatchFunc = changed,
            cancelFunc = function(previous)
                if currentId ~= nil then
                    set(currentId)
                elseif type(previous) == "table" and previous.r then
                    set(Looks.Hex(previous.r, previous.g, previous.b))
                end
            end,
        })
        starting = false
        return true
    end
    if type(picker.SetColorRGB) == "function" then -- the older picker: callbacks live on the frame
        picker.hasOpacity = false
        picker.previousValues = { r = rgb[1], g = rgb[2], b = rgb[3] }
        picker.func = function()
            local r, g, b = picker:GetColorRGB()
            set(Looks.Hex(r, g, b))
        end
        picker.opacityFunc = nil
        picker.cancelFunc = function(previous)
            if currentId ~= nil then
                set(currentId)
            elseif type(previous) == "table" and previous.r then
                set(Looks.Hex(previous.r, previous.g, previous.b))
            end
        end
        picker:SetColorRGB(rgb[1], rgb[2], rgb[3])
        picker:Hide()
        picker:Show()
        return true
    end
    return false
end

---------------------------------------------------------------------------------------------
-- Textures
---------------------------------------------------------------------------------------------

local TILED_GROUPS = { Patterns = true, Organic = true, Material = true }
local function fill(id, label, file, group)
    return { id = id, label = label, path = FILL_DIR .. "Fill_" .. file, tiled = TILED_GROUPS[group] == true, group = group }
end
-- A texture with colours of its own (a rainbow stays a rainbow): the fill colour does not tint it, opacity still applies.
local function color(id, label, group)
    return { id = id, label = label, path = FILL_DIR .. "Fill_" .. id, raw = true, group = group }
end

local BUILTIN = {
    { id = "flat",     label = "Flat",               path = WHITE, group = "Basic" },
    { id = "gradient", label = "Fade in from left",  path = WHITE, gradient = true, group = "Basic" },
    { id = "smooth",   label = "Health bar texture", path = "Interface\\TargetingFrame\\UI-StatusBar", group = "Blizzard" },
    { id = "raid",     label = "Raid bar texture",   path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill", group = "Blizzard" },
    { id = "resource", label = "Raid power texture", path = "Interface\\RaidFrame\\Raid-Bar-Resource-Fill", group = "Blizzard" },
    { id = "skills",   label = "Skill bar texture",  path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar", group = "Blizzard" },
    { id = "loading",  label = "Loading bar texture", path = "Interface\\Glues\\LoadingBar\\Loading-BarFill", group = "Blizzard" },
    fill("gloss", "Glass (light top, dark bottom)", "gloss", "Soft"),
    fill("bevel", "Bevel (light to dark)", "bevel", "Soft"),
    fill("cylinder", "Cylinder (bright middle)", "cylinder", "Soft"),
    fill("inset", "Inset (dark to light)", "inset", "Soft"),
    fill("top_shine", "Top shine", "top_shine", "Soft"),
    fill("edge_glow", "Rim glow (top and bottom)", "edge_glow", "Soft"),
    fill("fade_right", "Fade out to the right", "fade_right", "Soft"),
    fill("fade_left", "Fade out to the left", "fade_left", "Soft"),
    fill("fade_both", "Fade at both ends", "fade_both", "Soft"),
    { id = "stripes", label = "Diagonal stripes", path = DOT_DIR .. "Stripes", tiled = true, group = "Patterns" },
    fill("stripes_back", "Diagonal stripes, other way", "stripes_back", "Patterns"),
    fill("stripes_wide", "Wide diagonal stripes", "stripes_wide", "Patterns"),
    { id = "dash_v", label = "Vertical lines", path = DOT_DIR .. "DashH2", tiled = true, group = "Patterns" },
    { id = "dash_v_wide", label = "Vertical lines, wide", path = DOT_DIR .. "DashH8", tiled = true, group = "Patterns" },
    { id = "dash_h", label = "Horizontal lines", path = DOT_DIR .. "DashV4", tiled = true, group = "Patterns" },
    { id = "dash_h_wide", label = "Horizontal lines, wide", path = DOT_DIR .. "DashV8", tiled = true, group = "Patterns" },
    fill("scanlines", "Scanlines", "scanlines", "Patterns"),
    fill("crosshatch", "Crosshatch", "crosshatch", "Patterns"),
    fill("grid", "Grid", "grid", "Patterns"),
    fill("checker", "Checkerboard", "checker", "Patterns"),
    fill("dots", "Dots", "dots", "Patterns"),
    fill("dots_big", "Big dots", "dots_big", "Patterns"),
    fill("diamonds", "Diamonds", "diamonds", "Patterns"),
    fill("zigzag", "Zigzag", "zigzag", "Patterns"),
    fill("chevron", "Chevrons", "chevron", "Patterns"),
    fill("waves", "Waves", "waves", "Patterns"),
    fill("bricks", "Bricks", "bricks", "Patterns"),
    fill("carbon", "Carbon fibre", "carbon", "Patterns"),
    fill("noise", "Noise", "noise", "Patterns"),
    fill("brushed", "Brushed metal", "brushed", "Patterns"),
    -- more shadings and bar shapes (stretched over the bar)
    fill("tube", "Tube (round highlight)", "tube", "Soft"),
    fill("chrome", "Chrome bands", "chrome", "Soft"),
    fill("glass_strong", "Glass, strong", "glass_strong", "Soft"),
    fill("center_glow", "Glow in the middle", "center_glow", "Soft"),
    fill("dark_edges", "Dark edges", "dark_edges", "Soft"),
    fill("split", "Two tones (light over dark)", "split", "Soft"),
    fill("stairs", "Four steps", "stairs", "Soft"),
    fill("capsule", "Capsule (rounded ends)", "capsule", "Bar shapes"),
    fill("sweep", "Bright leading edge", "sweep", "Bar shapes"),
    fill("segments5", "Segments, 5 (20% each)", "segments5", "Bar shapes"),
    fill("segments10", "Segments, 10 (10% each)", "segments10", "Bar shapes"),
    fill("segments20", "Segments, 20 (5% each)", "segments20", "Bar shapes"),
    -- geometric patterns
    fill("hexagons", "Hexagons", "hexagons", "Patterns"),
    fill("triangles", "Triangles", "triangles", "Patterns"),
    fill("argyle", "Argyle diamonds", "argyle", "Patterns"),
    fill("plaid", "Plaid", "plaid", "Patterns"),
    fill("houndstooth", "Houndstooth", "houndstooth", "Patterns"),
    fill("stars", "Sparkles", "stars", "Patterns"),
    fill("pluses", "Crosses", "pluses", "Patterns"),
    fill("rings", "Rings", "rings", "Patterns"),
    -- nature
    fill("clouds", "Clouds", "clouds", "Organic"),
    fill("marble", "Marble", "marble", "Organic"),
    fill("wood", "Wood grain", "wood", "Organic"),
    fill("camo", "Camouflage", "camo", "Organic"),
    fill("leopard", "Leopard spots", "leopard", "Organic"),
    fill("cracks", "Cracked earth", "cracks", "Organic"),
    fill("veins", "Glowing veins", "veins", "Organic"),
    fill("bubbles", "Bubbles", "bubbles", "Organic"),
    fill("scales", "Fish scales", "scales", "Organic"),
    fill("ripples", "Water ripples", "ripples", "Organic"),
    fill("sand", "Sand", "sand", "Organic"),
    fill("zebra", "Zebra", "zebra", "Organic"),
    -- materials
    fill("leather", "Leather", "leather", "Material"),
    fill("cloth", "Woven cloth", "cloth", "Material"),
    fill("basket", "Basket weave", "basket", "Material"),
    fill("scratched", "Scratched metal", "scratched", "Material"),
    fill("tiles", "Beveled tiles", "tiles", "Material"),
    fill("rivets", "Rivets", "rivets", "Material"),
    fill("louvers", "Louvers", "louvers", "Material"),
    -- their own colours: the fill color does not tint these, only the opacity applies
    color("rainbow", "Rainbow", "Colorful (own colors)"),
    color("fire", "Fire", "Colorful (own colors)"),
    color("lava", "Lava", "Colorful (own colors)"),
    color("bloodred", "Blood", "Colorful (own colors)"),
    color("sunset", "Sunset", "Colorful (own colors)"),
    color("plasma", "Plasma", "Colorful (own colors)"),
    color("aurora", "Aurora", "Colorful (own colors)"),
    color("ice", "Ice", "Colorful (own colors)"),
    color("ocean_v", "Ocean (light to deep)", "Colorful (own colors)"),
    color("fire_v", "Flame (top to bottom)", "Colorful (own colors)"),
    color("toxic", "Toxic", "Colorful (own colors)"),
    color("goldbar", "Gold", "Colorful (own colors)"),
    color("steelblue", "Steel blue", "Colorful (own colors)"),
}
local BUILTIN_BY_ID = {}
for _, entry in ipairs(BUILTIN) do BUILTIN_BY_ID[entry.id] = entry end

-- LibSharedMedia-3.0, when some other addon brought it: every statusbar texture it knows, as "lsm:<name>".
local function sharedMedia()
    if type(LibStub) ~= "table" and type(LibStub) ~= "function" then return nil end
    local ok, lib = pcall(LibStub, "LibSharedMedia-3.0", true)
    if ok and type(lib) == "table" and type(lib.HashTable) == "function" then return lib end
    return nil
end

local mediaCache, mediaSignature = {}, nil
local function mediaEntries()
    local lib = sharedMedia()
    if not lib then
        if mediaSignature ~= "" then mediaCache, mediaSignature = {}, "" end
        return mediaCache
    end
    local ok, hash = pcall(lib.HashTable, lib, "statusbar")
    if not ok or type(hash) ~= "table" then return mediaCache end
    local names = {}
    for name, path in pairs(hash) do
        if type(name) == "string" and type(path) == "string" then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    local signatureParts = {}
    for _, name in ipairs(names) do
        local path = hash[name]
        signatureParts[#signatureParts + 1] = #name .. ":" .. name .. #path .. ":" .. path
    end
    local signature = table.concat(signatureParts, "\1")
    if signature == mediaSignature then return mediaCache end
    mediaCache, mediaSignature = {}, signature
    for i, name in ipairs(names) do
        mediaCache[i] = { id = "lsm:" .. name, label = name, literal = true, path = hash[name], group = "Shared media" }
    end
    return mediaCache
end

-- A new list: the built-in textures, then the shared-media ones (re-read whenever the library got new entries).
function Looks.Textures()
    local list = { kind = "texture" }
    for _, entry in ipairs(BUILTIN) do list[#list + 1] = entry end
    for _, entry in ipairs(mediaEntries()) do list[#list + 1] = entry end
    return list
end

-- One entry for any saved id. A shared-media id is looked up live (the library may load after the settings did); an id
-- nothing knows answers the flat texture, so a removed addon never leaves an invisible bar.
function Looks.Texture(id)
    local entry = BUILTIN_BY_ID[id]
    if entry then return entry end
    if type(id) == "string" and id:sub(1, 4) == "lsm:" then
        local lib = sharedMedia()
        if lib and type(lib.Fetch) == "function" then
            local ok, path = pcall(lib.Fetch, lib, "statusbar", id:sub(5), true)
            if ok and type(path) == "string" then return { id = id, label = id:sub(5), literal = true, path = path, group = "Shared media" } end
        end
    end
    return BUILTIN_BY_ID.flat
end

-- Adds to a module's own list (it keeps its own order and ids) every catalog entry it lacks. Returns the list.
function Looks.Merge(list)
    local textures, byId, live = Looks.Textures(), {}, {}
    for _, entry in ipairs(list) do
        if entry.id ~= nil then byId[entry.id] = entry end
    end
    for _, entry in ipairs(textures) do
        local id = entry.id
        live[id] = true
        local existing = byId[id]
        if existing and existing ~= entry and type(id) == "string" and id:sub(1, 4) == "lsm:" then
            for key in pairs(existing) do existing[key] = nil end
            for key, value in pairs(entry) do existing[key] = value end
        elseif not existing and not (list.noGradient and entry.gradient) then
            list[#list + 1] = entry
            byId[id] = entry
        end
    end
    for i = #list, 1, -1 do
        local id = list[i].id
        if type(id) == "string" and id:sub(1, 4) == "lsm:" and not live[id] then table.remove(list, i) end
    end
    return list
end

---------------------------------------------------------------------------------------------
-- One drop-down for every menu
---------------------------------------------------------------------------------------------

local ROWS, ROW_HEIGHT = 14, 20
local menu

local function build()
    menu = CreateFrame("Frame", "Ready2QuestCombat_PickList", UIParent, "BackdropTemplate")
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "Ready2QuestCombat_PickList") end -- Escape closes it
    menu:SetFrameStrata("TOOLTIP") -- above every settings window, whatever strata and levels its rows use
    menu:EnableMouse(true)
    menu:EnableMouseWheel(true)
    if BIT.UI and BIT.UI.Backdrop then BIT.UI.Backdrop(menu, 0.08, 1) end
    -- The tooltip backdrop is translucent by itself: an opaque floor keeps the rows behind the menu from showing through.
    menu.floor = menu:CreateTexture(nil, "BACKGROUND", nil, 1)
    menu.floor:SetPoint("TOPLEFT", menu, "TOPLEFT", 3, -3)
    menu.floor:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -3, 3)
    menu.floor:SetColorTexture(0.05, 0.05, 0.06, 1)
    menu.buttons = {}
    menu.offset = 0
    menu.hasEvent = pcall(menu.RegisterEvent, menu, "GLOBAL_MOUSE_DOWN")
    menu:SetScript("OnEvent", function(self)
        if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
    end)
    -- It never outlives the window that opened it, and a client without GLOBAL_MOUSE_DOWN still closes it on an outside click.
    menu:SetScript("OnUpdate", function(self)
        local owner = self.owner
        if owner and owner.IsVisible and not owner:IsVisible() then self:Hide() return end
        if not self.hasEvent and type(IsMouseButtonDown) == "function" and IsMouseButtonDown("LeftButton")
            and not self:IsMouseOver() and not (owner and owner:IsMouseOver()) then
            self:Hide()
        end
    end)
    menu.scroll = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    menu.scroll:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -6, 2)
    for i = 1, ROWS do
        local button = CreateFrame("Button", nil, menu)
        button:SetHeight(ROW_HEIGHT)
        if BIT.UI and BIT.UI.RoundHighlight then BIT.UI.RoundHighlight(button) end
        button.swatch = button:CreateTexture(nil, "ARTWORK")
        button.swatch:SetSize(40, 12)
        button.swatch:SetPoint("LEFT", 8, 0)
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.text:SetJustifyH("LEFT")
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -4 - (i - 1) * ROW_HEIGHT)
        button:SetPoint("RIGHT", menu, "RIGHT", -1, 0)
        menu.buttons[i] = button
    end
    menu:SetScript("OnMouseWheel", function(self, delta)
        local top = math.max(0, #self.list - ROWS)
        self.offset = math.max(0, math.min(top, self.offset - delta * 3))
        self:Render()
    end)
    function menu:Render()
        local list, current = self.list, self.current
        for i = 1, ROWS do
            local button, entry = self.buttons[i], list[self.offset + i]
            if not entry then
                button:Hide()
            else
                button:Show()
                local hasSwatch = entry.rgb ~= nil or entry.path ~= nil
                button.swatch:SetShown(hasSwatch and not entry.header)
                button.swatch:SetHorizTile(false)
                button.swatch:SetVertTile(false)
                local icons = list.kind == "icon"
                if entry.rgb then
                    button.swatch:SetSize(14, 12)
                    button.swatch:SetVertexColor(1, 1, 1, 1)
                    button.swatch:SetColorTexture(entry.rgb[1], entry.rgb[2], entry.rgb[3], 1)
                elseif entry.path and icons then
                    button.swatch:SetSize(16, 16)
                    button.swatch:SetVertexColor(1, 1, 1, 1)
                    button.swatch:SetTexture(entry.path)
                elseif entry.path then
                    button.swatch:SetSize(40, 12)
                    button.swatch:SetTexture(entry.path, entry.tiled and "REPEAT" or nil, entry.tiled and "REPEAT" or nil)
                    button.swatch:SetHorizTile(entry.tiled or false)
                    button.swatch:SetVertTile(entry.tiled or false)
                    if entry.raw then button.swatch:SetVertexColor(1, 1, 1, 1) else button.swatch:SetVertexColor(1, 0.62, 0.2, 1) end
                end
                button.text:ClearAllPoints()
                if entry.header then
                    button.text:SetPoint("LEFT", 6, 0)
                    button.text:SetText("|cff888888" .. BIT.L(entry.label) .. "|r")
                else
                    local label = entry.literal and entry.label or BIT.L(entry.label)
                    button.text:SetPoint("LEFT", hasSwatch and ((entry.rgb and 28) or (icons and 30) or 54) or 8, 0)
                    button.text:SetText(entry.id == current and ("|cffffd100" .. label .. "|r") or label)
                end
                button:SetEnabled(not entry.header)
                button:SetScript("OnClick", function()
                    if entry.header then return end
                    local pick = self.pick
                    self:Hide()
                    pick(entry.id)
                end)
            end
        end
        local more = #list - ROWS
        self.scroll:SetText(more > 0 and string.format(BIT.L("%d-%d of %d"), self.offset + 1,
            math.min(#list, self.offset + ROWS), #list) or "")
    end
end

-- One header row per group, groups in one fixed order whatever order a module's list (or the catalog) lists them in. Entries
-- without a group stay first, in their own order; a group nobody knows comes after the known ones.
local GROUP_ORDER = { Basic = 1, Blizzard = 2, Soft = 3, ["Bar shapes"] = 4, Patterns = 5, Organic = 6, Material = 7,
    ["Colorful (own colors)"] = 8, ["Shield art"] = 9, ["Shared media"] = 10 }

local function withHeaders(list)
    local grouped = false
    for _, entry in ipairs(list) do
        if entry.group then grouped = true break end
    end
    if not grouped then return list end
    local loose, buckets, names = {}, {}, {}
    for _, entry in ipairs(list) do
        local group = entry.group
        if not group then
            loose[#loose + 1] = entry
        else
            if not buckets[group] then
                buckets[group] = {}
                names[#names + 1] = group
            end
            table.insert(buckets[group], entry)
        end
    end
    local seen = {}
    for i, name in ipairs(names) do seen[name] = i end
    table.sort(names, function(a, b)
        local ra, rb = GROUP_ORDER[a] or (100 + seen[a]), GROUP_ORDER[b] or (100 + seen[b])
        return ra < rb
    end)
    local out = { kind = list.kind }
    for _, entry in ipairs(loose) do out[#out + 1] = entry end
    for _, name in ipairs(names) do
        out[#out + 1] = { id = "~" .. name, label = name, header = true }
        for _, entry in ipairs(buckets[name]) do out[#out + 1] = entry end
    end
    return out
end

-- Opens (or closes, when it is already open for `owner`) the drop-down under `owner`; pick(id) runs on a click.
function Looks.PickList(owner, list, current, pick)
    if not menu then build() end
    if menu:IsShown() and menu.owner == owner then menu:Hide() return end
    menu.owner, menu.pick, menu.current = owner, pick, current
    local level = (owner.GetFrameLevel and owner:GetFrameLevel() or 0) + 20
    menu:SetFrameLevel(level)
    for _, button in ipairs(menu.buttons) do button:SetFrameLevel(level + 1) end
    menu.list = withHeaders(list)
    menu.offset = 0
    for i, entry in ipairs(menu.list) do
        if entry.id == current then menu.offset = math.max(0, math.min(#menu.list - ROWS, i - 4)) break end
    end
    local rows = math.min(ROWS, #menu.list)
    menu:SetSize(math.max(owner:GetWidth() or 180, 190), rows * ROW_HEIGHT + 8)
    menu:ClearAllPoints()
    local bottom = owner.GetBottom and owner:GetBottom() or nil
    if bottom and bottom < rows * ROW_HEIGHT + 40 then
        menu:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2)
    else
        menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    end
    menu:Render()
    menu:Show()
end

function Looks.ClosePickList()
    if menu then menu:Hide() end
end

-- The colour list entry a module's option row should show and what a click does, shared by every row builder:
-- a colour list adds the custom colour, and "Custom colour..." opens the picker instead of picking a value.
function Looks.Choose(owner, list, current, set)
    Looks.PickList(owner, list, current, function(id)
        if id == "custom" then
            Looks.PickColor(current, set)
        else
            set(id)
        end
    end)
end
