-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: public module discovery and callbacks. See API.md.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
local ADDON, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local Root = { API_VERSION = 1 }
local internal = {}
BIT.API = internal

local subs, subOrder = {}, {}
local events, eventOrder = {}, {}

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function declared(event)
    assert(not isSecret(event) and type(event) == "string" and events[event],
        "Ready2QuestCombat_API: unknown event")
    return events[event]
end

function internal.Register(name, api, opts)
    assert(type(name) == "string" and type(api) == "table" and type(api.API_VERSION) == "number",
        "BIT.API.Register: a name and versioned API are required")
    if not subs[name] then subOrder[#subOrder + 1] = name end
    subs[name] = { api = api, module = opts and opts.module or name }
end

function internal.DeclareEvent(event, module, log)
    assert(type(event) == "string" and not events[event], "BIT.API.DeclareEvent: event must be unique")
    events[event] = { module = module, log = log, list = {}, reported = {} }
    eventOrder[#eventOrder + 1] = event
end

function internal.HasListeners(event)
    local entry = events[event]
    return entry ~= nil and BIT.IsRunning(entry.module) and #entry.list > 0
end

function internal.Fire(event, ...)
    if not internal.HasListeners(event) then return end
    local entry, snapshot = events[event], {}
    for i, listener in ipairs(entry.list) do snapshot[i] = listener end
    for _, listener in ipairs(snapshot) do
        -- New registrations wait for the next event; removals take effect immediately.
        if not listener.dead then
            local ok, err = pcall(listener.func, event, ...)
            if not ok then
                err = tostring(err)
                if not entry.reported[err] then
                    entry.reported[err] = true
                    local text = "API callback error (" .. tostring(listener.owner) .. ", " .. event .. "): " .. err
                    local logged, logError = pcall(entry.log or BIT.Say, text)
                    if not logged then BIT.Say(text .. "; logging failed: " .. tostring(logError)) end
                end
            end
        end
    end
end

function Root.GetAddonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(get) ~= "function" then return nil end
    local ok, value = pcall(get, BIT.name or ADDON, "Version")
    if ok and not isSecret(value) and type(value) == "string" then return value end
end

function Root.Get(name)
    if isSecret(name) or type(name) ~= "string" then return nil end
    local sub = subs[name]
    if sub and BIT.IsRunning(sub.module) then return sub.api end
end

function Root.GetVersion(name)
    local api = Root.Get(name)
    return api and api.API_VERSION or nil
end

function Root.GetModules()
    local names = {}
    for _, name in ipairs(subOrder) do
        if Root.Get(name) then names[#names + 1] = name end
    end
    return names
end

function Root.GetEvents()
    local names = {}
    for i, name in ipairs(eventOrder) do names[i] = name end
    return names
end

function Root.RegisterCallback(owner, event, func)
    assert(not isSecret(owner) and owner ~= nil, "Ready2QuestCombat_API.RegisterCallback: owner is required")
    assert(type(func) == "function", "Ready2QuestCombat_API.RegisterCallback: func must be a function")
    local entry = declared(event)
    for _, listener in ipairs(entry.list) do
        if listener.owner == owner then
            listener.func = func
            return
        end
    end
    entry.list[#entry.list + 1] = { owner = owner, func = func }
end

function Root.UnregisterCallback(owner, event)
    if isSecret(owner) or isSecret(event) or owner == nil then return end
    local function drop(entry)
        for i = #entry.list, 1, -1 do
            local listener = entry.list[i]
            if listener.owner == owner then
                listener.dead = true
                table.remove(entry.list, i)
            end
        end
    end
    if event ~= nil then
        drop(declared(event))
    else
        for _, entry in pairs(events) do drop(entry) end
    end
end

Ready2QuestCombat_API = Root

BIT.RegisterCommand("api", function()
    BIT.Say("API " .. Root.API_VERSION)
    for _, name in ipairs(subOrder) do
        local sub = subs[name]
        BIT.Say(string.format("  %s v%s: %s", name, sub.api.API_VERSION, Root.Get(name) and "on" or "off"))
    end
    for _, event in ipairs(eventOrder) do
        BIT.Say(string.format("  %s: %d listener(s)", event, #events[event].list))
    end
end)
