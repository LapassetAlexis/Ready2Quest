-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: the language of the settings, tooltips and chat lines.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The English text in the code is the key: BIT.L("Reset this tab") gives the text in the language in use,
-- or the same text when that language has no entry for it (English needs none). A language is a set of
-- files under Locales\xxXX\ that call BIT.RegisterLocale("xxXX", { ["English text"] = "translation" });
-- both .toc files list them after this file. The client's own language is used, or the one /upt lang
-- chose. Keep every %s and %d of a text in the translation, in the same order.
--
-- Call BIT.L where the text is shown, never at file load: the saved language can't be read before
-- ADDON_LOADED, and until then every text stays English. A language change applies after /reload.
-- SpellDamageInfo keeps its own language switch (/sdi lang); the spell parser's wordings are packs
-- of their own (Modules\SpellDamageInfo\Parser_xxXX.lua).

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local packs, codes = {}, {} -- code -> { [English text] = translation }; the codes in the order their files load
local active, activeCode    -- the pack of the language in use (nil while English is shown), and its code
local missing = {}          -- English texts asked for while a language was in use that has no entry for them
local missingCount = 0
local MAX_MISSING = 400     -- a text built from numbers would otherwise fill this without end

function BIT.RegisterLocale(code, entries)
  local pack = packs[code]
  if not pack then
    pack = {}
    packs[code] = pack
    codes[#codes + 1] = code
  end
  for text, translation in pairs(entries) do pack[text] = translation end
end

function BIT.L(text)
  if active then
    local translation = active[text]
    if translation then return translation end
    if type(text) == "string" and text ~= "" and not missing[text] and missingCount < MAX_MISSING then
      missing[text] = true
      missingCount = missingCount + 1
    end
  end
  return text
end

-- "de", "deDE" and "DEDE" all name deDE; "en", "enUS" and "enGB" name the English of the code (false).
-- Anything else, including "auto", names nothing (nil).
local function find(name)
  name = type(name) == "string" and name:lower() or ""
  if name:sub(1, 2) == "en" then return false end
  for _, code in ipairs(codes) do
    if code:lower() == name then return code end
  end
  for _, code in ipairs(codes) do
    if code:sub(1, 2):lower() == name then return code end
  end
end

local function resolve()
  local code = find(BIT.DB().language)
  if code == nil then
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if type(get) == "function" then
      local ok, locale = pcall(get, "textLocale")
      if ok then code = find(locale) end
    end
    if code == nil then code = find(GetLocale()) end
  end
  active, activeCode = code and packs[code] or nil, code or nil
end

local function command(rest)
  local say = BIT.Say
  local word = (rest or ""):match("^%S+")
  if word == "missing" then
    local list = {}
    for text in pairs(missing) do list[#list + 1] = text end
    table.sort(list)
    say(string.format(BIT.L("%d texts shown so far have no translation in this language."), #list))
    for i = 1, math.min(#list, 40) do say("  " .. list[i]) end
  elseif word then
    if word:lower() ~= "auto" and find(word) == nil then
      say(string.format(BIT.L("Unknown language %s. Use auto, en or one of: %s."), word, table.concat(codes, ", ")))
      return
    end
    BIT.DB().language = word:lower() ~= "auto" and word or nil
    say(BIT.L("The language changes after /reload."))
  else
    say(string.format(BIT.L("Language: %s. /upt lang auto, /upt lang en, /upt lang <code> (%s) or /upt lang missing."),
      activeCode or "en", table.concat(codes, ", ")))
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
  if name ~= BIT.name then return end
  self:UnregisterEvent("ADDON_LOADED")
  resolve()
  BIT.RegisterCommand("lang", command)
end)
