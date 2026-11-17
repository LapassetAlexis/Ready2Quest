-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Where the addon's CPU time goes: how long the handlers of its frames and a few of its heavier steps take, kept per
-- name for the session (/upt perf), with the slowest single calls and how much memory each call allocated.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The game's addon profiler only knows an addon as a whole ("DoesItDiePlus: 77% of all addon time, peak 77 ms"); this says
-- which part. Nothing here replaces a global or a frame method (a replaced global taints it for the game's own code):
-- a module hands its own handler to Perf.Wrap, or its frame to Perf.Watch, which wraps the handler already set.
--
--   Perf.Wrap(label, fn[, memory])     fn timed under `label`; the same function when the client has no clock
--   Perf.Watch(frame, script, label)   the frame's OnUpdate / OnEvent script, timed
--   Perf.Begin() / Perf.End(label, t)  a step inside a handler
--
-- A call that allocated memory and then ran long has often paid for a garbage collection step that the allocation
-- started: its "kb" is the memory change over the call (a drop is a collection that ran inside it).

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
if not BIT then return end

local Perf = {}
BIT.Perf = Perf

local clock = type(debugprofilestop) == "function" and debugprofilestop or nil
local SLOW_MS, MAX_SLOW = 8, 40

local sections = {}   -- label -> { calls, ms, peak, slow, kb }
local slowCalls = {}  -- a ring of the latest calls of SLOW_MS or more: { at, label, ms, kb }
local slowNext = 1
local startedAt

Perf.sections, Perf.slowCalls = sections, slowCalls

if not clock then
  -- no timer: every entry point is a harmless pass-through
  function Perf.Wrap(_, fn) return fn end
  function Perf.Watch() end
  function Perf.Begin() end
  function Perf.End() end
  function Perf.Attach() end
  return
end

local function record(label, ms, kb)
  local s = sections[label]
  if not s then
    s = { calls = 0, ms = 0, peak = 0, slow = 0, kb = 0 }
    sections[label] = s
  end
  s.calls = s.calls + 1
  s.ms = s.ms + ms
  if kb then s.kb = s.kb + kb end
  if ms > s.peak then s.peak = ms end
  if ms >= SLOW_MS then
    s.slow = s.slow + 1
    slowCalls[slowNext] = { at = GetTime(), label = label, ms = ms, kb = kb }
    slowNext = slowNext % MAX_SLOW + 1
  end
end

local function finish(label, t0, m0, ...)
  record(label, clock() - t0, m0 and (collectgarbage("count") - m0) or nil)
  return ...
end

function Perf.Wrap(label, fn, memory)
  if type(fn) ~= "function" then return fn end
  if memory then
    return function(...)
      local m0 = collectgarbage("count")
      return finish(label, clock(), m0, fn(...))
    end
  end
  return function(...) return finish(label, clock(), nil, fn(...)) end
end

function Perf.Watch(frame, script, label)
  if type(frame) ~= "table" and type(frame) ~= "userdata" then return end
  local ok, fn = pcall(frame.GetScript, frame, script)
  if not ok or type(fn) ~= "function" then return end
  pcall(frame.SetScript, frame, script, Perf.Wrap(label .. " " .. script, fn, script == "OnUpdate"))
end

function Perf.Begin() return clock() end

function Perf.End(label, t0)
  if t0 then record(label, clock() - t0, nil) end
end

---------------------------------------------------------------------------------------------
-- The report
---------------------------------------------------------------------------------------------

local function sortedLabels()
  local labels = {}
  for label in pairs(sections) do labels[#labels + 1] = label end
  table.sort(labels, function(a, b) return sections[a].ms > sections[b].ms end)
  return labels
end

-- Lines for chat: the busiest parts first.
function Perf.Report(limit)
  local lines = {}
  local labels = sortedLabels()
  local total = 0
  for _, label in ipairs(labels) do total = total + sections[label].ms end
  local seconds = startedAt and (GetTime() - startedAt) or 0
  lines[1] = string.format("perf: %.0f ms in %d s across %d parts (a part's time includes the parts timed inside it); "
    .. "/upt perf slow lists the slowest calls, /upt perf reset starts over", total, seconds, #labels)
  for i = 1, math.min(limit or 14, #labels) do
    local label, s = labels[i], sections[labels[i]]
    lines[#lines + 1] = string.format("%-38s %7d calls %9.1f ms %7.3f avg %7.1f peak %4d >=%dms %+8.0f KB", label, s.calls,
      s.ms, s.ms / math.max(1, s.calls), s.peak, s.slow, SLOW_MS, s.kb)
  end
  return lines
end

-- The slowest recent calls, newest last; "(GC?)" where memory fell during the call.
function Perf.SlowLines(limit)
  local list = {}
  for _, c in pairs(slowCalls) do list[#list + 1] = c end
  table.sort(list, function(a, b) return a.at < b.at end)
  local lines = {}
  for i = math.max(1, #list - (limit or 15) + 1), #list do
    local c = list[i]
    lines[#lines + 1] = string.format("t=%.1f %-38s %7.1f ms%s", c.at, c.label, c.ms,
      c.kb and string.format(" %+.0f KB%s", c.kb, c.kb < -50 and " (GC?)" or "") or "")
  end
  if #lines == 0 then lines[1] = string.format("no call has taken %d ms or more yet", SLOW_MS) end
  return lines
end

function Perf.Reset()
  for label in pairs(sections) do sections[label] = nil end
  for i = #slowCalls, 1, -1 do slowCalls[i] = nil end
  slowNext = 1
  startedAt = GetTime()
end

-- The saved variables keep the live tables, so they hold this session's numbers after a /reload or a logout, where they
-- can be read from the file. Called when the addon's own settings are loaded.
function Perf.Attach(db)
  startedAt = startedAt or GetTime()
  if type(db) == "table" then db.perf = { sections = sections, slow = slowCalls } end
  if BIT.RegisterCommand then
    BIT.RegisterCommand("perf", function(arg)
      arg = type(arg) == "string" and arg:lower() or ""
      if arg == "reset" then
        Perf.Reset()
        BIT.Say("perf: counters cleared")
        return
      end
      for _, line in ipairs(arg == "slow" and Perf.SlowLines() or Perf.Report()) do BIT.Say(line) end
    end)
  end
end
