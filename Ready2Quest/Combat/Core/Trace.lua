-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Stack traces that concern this addon, kept for the Debug tab: Lua errors whose message or
-- stack names the addon's folder, and the client's "blocked from an action only available to
-- the Blizzard UI" reports that blame it. Kept in memory for the session only (a reload starts
-- over), newest last, repeats counted instead of stored twice.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- Loaded right after Init.lua, so errors raised while the other files load are caught too.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
if not BIT then return end

local MAX_ENTRIES = 50
local MAX_STACK = 4000 -- characters kept of one stack

local entries = {}
local listeners = {}
local Trace = { entries = entries }
BIT.Trace = Trace

local function text(v)
  if type(v) ~= "string" then return nil end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then return nil end
  end
  return v
end

local function stackFrom(level)
  if type(debugstack) ~= "function" then return "" end
  local ok, stack = pcall(debugstack, level)
  stack = ok and text(stack) or ""
  if #stack > MAX_STACK then stack = stack:sub(1, MAX_STACK) .. "\n..." end
  return stack
end

local function mentionsUs(s)
  return type(s) == "string" and s:find(BIT.name, 1, true) ~= nil
end

local function notify()
  for _, fn in ipairs(listeners) do pcall(fn) end
end

local function record(kind, message, stack)
  for _, e in ipairs(entries) do
    if e.kind == kind and e.message == message and e.stack == stack then
      e.count = e.count + 1
      e.time = type(date) == "function" and date("%H:%M:%S") or ""
      notify()
      return
    end
  end
  if #entries >= MAX_ENTRIES then table.remove(entries, 1) end
  entries[#entries + 1] = {
    kind = kind, message = message, stack = stack, count = 1,
    time = type(date) == "function" and date("%H:%M:%S") or "",
  }
  notify()
end

function Trace.Clear()
  for i = #entries, 1, -1 do entries[i] = nil end
  notify()
end

-- fn() is called after every change of the list.
function Trace.OnChange(fn)
  if type(fn) == "function" then listeners[#listeners + 1] = fn end
end

-- The whole list as one text, newest first, ready to be copied into a report.
function Trace.Text()
  local out = {}
  for i = #entries, 1, -1 do
    local e = entries[i]
    out[#out + 1] = string.format("[%s] %s%s\n%s\n%s", e.time, e.kind,
      e.count > 1 and (" x" .. e.count) or "", e.message, e.stack)
  end
  return table.concat(out, "\n\n")
end

-- Lua errors. The handler in place stays in charge (the game's error window, BugGrabber, ...):
-- ours only looks at the message and the stack first, and nothing it does may raise.
if type(geterrorhandler) == "function" and type(seterrorhandler) == "function" then
  local previous = geterrorhandler()
  seterrorhandler(function(message, ...)
    pcall(function()
      local msg = text(message) or tostring(message)
      local stack = stackFrom(4)
      if mentionsUs(msg) or mentionsUs(stack) then record("Lua error", msg, stack) end
    end)
    if type(previous) == "function" then return previous(message, ...) end
  end)
end

-- Blocked and forbidden protected calls: the event comes from inside the refused call, so the
-- stack taken here is the path that ran tainted.
local watcher = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "LUA_WARNING" }) do
  pcall(watcher.RegisterEvent, watcher, event)
end
watcher:SetScript("OnEvent", function(_, event, a, b)
  if event == "LUA_WARNING" then
    local msg = text(b) or text(a)
    if mentionsUs(msg) then record("Lua warning", msg, stackFrom(3)) end
    return
  end
  if text(a) ~= BIT.name then return end
  record(event == "ADDON_ACTION_FORBIDDEN" and "Forbidden action" or "Blocked action",
    tostring(text(b) or "?"), stackFrom(3))
end)
