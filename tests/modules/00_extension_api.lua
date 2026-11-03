-- Contrat de l'API d'extension (v1.23.0) : ce sur quoi s'appuient les modules.
local Check, ResetWorld, NS, Mock = T.Check, T.ResetWorld, T.NS, T.Mock

ResetWorld()
NS.RegisterStrings({ TEST_EXT_KEY = "valeur fr" }, { TEST_EXT_KEY = "value en" })
Check("[API] RegisterStrings : clé lisible", NS.L.TEST_EXT_KEY == "valeur fr", NS.L.TEST_EXT_KEY)

NS.RegisterDefaults({ testExtDefault = 42 })
Check("[API] RegisterDefaults après lecture : appliqué", NS:DB().testExtDefault == 42)

local events = {}
NS:RegisterCallback("DEPARTURE", function(_, from) events[#events + 1] = "DEPARTURE:" .. tostring(from and from.name) end)
NS:RegisterCallback("RETURN", function(_, place) events[#events + 1] = "RETURN:" .. tostring(place and place.name) end)
_G.UnitFactionGroup = function() return "Alliance" end
Mock.world.mapID, Mock.world.subzone = 30, "Goldshire"
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Mock.now = Mock.now + 60
Mock.world.subzone = "Bois"
Mock:Fire("ZONE_CHANGED"); Mock:Advance(6)
Check("[API] DEPARTURE émis à la sortie confirmée", events[1] == "DEPARTURE:Goldshire", table.concat(events, ","))
Mock.world.subzone = "Goldshire"
Mock:Fire("ZONE_CHANGED")
Check("[API] RETURN émis au retour", events[2] == "RETURN:Goldshire", table.concat(events, ","))
Mock.world.subzone = "Bois"; Mock:Fire("ZONE_CHANGED"); Mock:Advance(2)
Mock.world.subzone = "Goldshire"; Mock:Fire("ZONE_CHANGED")
Check("[API] aller-retour avant le délai : ni départ ni retour", #events == 2, table.concat(events, ","))

ResetWorld()
NS:DB().departureEnabled = false
events = {}
Mock.world.mapID, Mock.world.subzone = 30, "Goldshire"
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Mock.now = Mock.now + 60
Mock.world.subzone = "Bois"; Mock:Fire("ZONE_CHANGED"); Mock:Advance(6)
Check("[API] module de départ coupé : DEPARTURE émis quand même", events[1] == "DEPARTURE:Goldshire", table.concat(events, ","))
Check("[API] module de départ coupé : pas d'alerte", NS.lastResults == nil)

Check("[API] AddCheck exposé", type(NS.AddCheck) == "function")
Check("[API] AddOptionPage exposé", type(NS.AddOptionPage) == "function")
Check("[API] RegisterModule exposé", type(NS.RegisterModule) == "function")
Check("[API] le harnais charge les fichiers du .toc", TOC_FILES and #TOC_FILES >= 15, TOC_FILES and #TOC_FILES)
_G.UnitFactionGroup = nil
