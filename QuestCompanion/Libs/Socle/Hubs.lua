-- Hubs.lua -- GÉNÉRÉ par tools/gen_hubs.py, ne pas éditer à la main
-- Zones sûres connues dès l'installation : capitales (drapeau CAPITAL du
-- client), villages, hubs et auberges-sous-zones, Era 1.15.9 et Forever 1.60.1.
-- [areaID] = { faction = "A"|"H"|"N", kind = "capital"|"town"|"inn"|"hub"|"start", name = nom anglais (repli) }
--   start : vallée de départ (niveaux 1-5) ; en partir ne déclenche aucune alerte.
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
local ADDON, ns = ...

ns.HUBS = {
	[1657] = { faction = "A", kind = "capital", name = "Darnassus" },  -- era+forever
	[1537] = { faction = "A", kind = "capital", name = "Ironforge" },  -- era+forever
	[1519] = { faction = "A", kind = "capital", name = "Stormwind City" },  -- era+forever
	[16509] = { faction = "A", kind = "capital", name = "Stormwind City" },  -- forever
	[1637] = { faction = "H", kind = "capital", name = "Orgrimmar" },  -- era+forever
	[1638] = { faction = "H", kind = "capital", name = "Thunder Bluff" },  -- era+forever
	[1497] = { faction = "H", kind = "capital", name = "Undercity" },  -- era+forever
	[348] = { faction = "A", kind = "town", name = "Aerie Peak" },  -- era+forever
	[256] = { faction = "A", kind = "start", name = "Aldrassil" },  -- era+forever
	[77] = { faction = "A", kind = "start", name = "Anvilmar" },  -- era+forever
	[415] = { faction = "A", kind = "town", name = "Astranaar" },  -- era+forever
	[442] = { faction = "A", kind = "town", name = "Auberdine" },  -- era+forever
	[3197] = { faction = "A", kind = "hub", name = "Chillwind Camp" },  -- era+forever
	[132] = { faction = "A", kind = "start", name = "Coldridge Valley" },  -- era+forever
	[42] = { faction = "A", kind = "town", name = "Darkshire" },  -- era+forever
	[16134] = { faction = "A", kind = "town", name = "Darkshire" },  -- era+forever
	[16161] = { faction = "A", kind = "town", name = "Darkshire" },  -- era+forever
	[2104] = { faction = "A", kind = "inn", name = "Deepwater Tavern" },  -- era+forever
	[186] = { faction = "A", kind = "town", name = "Dolanaar" },  -- era+forever
	[34] = { faction = "A", kind = "start", name = "Echo Ridge Mine" },  -- era+forever
	[16514] = { faction = "A", kind = "start", name = "Echo Ridge Mine" },  -- forever
	[1116] = { faction = "A", kind = "town", name = "Feathermoon Stronghold" },  -- era+forever
	[135] = { faction = "A", kind = "start", name = "Frostmane Hold" },  -- era+forever
	[87] = { faction = "A", kind = "town", name = "Goldshire" },  -- era+forever
	[16524] = { faction = "A", kind = "town", name = "Goldshire" },  -- forever
	[131] = { faction = "A", kind = "town", name = "Kharanos" },  -- era+forever
	[69] = { faction = "A", kind = "town", name = "Lakeshire" },  -- era+forever
	[150] = { faction = "A", kind = "town", name = "Menethil Harbor" },  -- era+forever
	[2418] = { faction = "A", kind = "hub", name = "Morgan's Vigil" },  -- era+forever
	[1438] = { faction = "A", kind = "hub", name = "Nethergarde Keep" },  -- era+forever
	[608] = { faction = "A", kind = "town", name = "Nijel's Point" },  -- era+forever
	[24] = { faction = "A", kind = "start", name = "Northshire Abbey" },  -- era+forever
	[23] = { faction = "A", kind = "start", name = "Northshire River" },  -- era+forever
	[9] = { faction = "A", kind = "start", name = "Northshire Valley" },  -- era+forever
	[16523] = { faction = "A", kind = "start", name = "Northshire Valley" },  -- forever
	[59] = { faction = "A", kind = "start", name = "Northshire Vineyards" },  -- era+forever
	[16520] = { faction = "A", kind = "start", name = "Northshire Vineyards" },  -- forever
	[320] = { faction = "A", kind = "town", name = "Refuge Pointe" },  -- era+forever
	[702] = { faction = "A", kind = "town", name = "Rut'theran Village" },  -- era+forever
	[108] = { faction = "A", kind = "town", name = "Sentinel Hill" },  -- era+forever
	[188] = { faction = "A", kind = "start", name = "Shadowglen" },  -- era+forever
	[257] = { faction = "A", kind = "start", name = "Shadowthread Cave" },  -- era+forever
	[271] = { faction = "A", kind = "town", name = "Southshore" },  -- era+forever
	[2369] = { faction = "A", kind = "town", name = "Southshore" },  -- era+forever
	[467] = { faction = "A", kind = "hub", name = "Stonetalon Peak" },  -- era+forever
	[2101] = { faction = "A", kind = "inn", name = "Stoutlager Inn" },  -- era+forever
	[3137] = { faction = "A", kind = "hub", name = "Talrendis Point" },  -- era+forever
	[16016] = { faction = "A", kind = "hub", name = "Talrendis Point" },  -- era+forever
	[489] = { faction = "A", kind = "hub", name = "Thalanaar" },  -- era+forever
	[17824] = { faction = "A", kind = "hub", name = "The Eventide" },  -- forever
	[144] = { faction = "A", kind = "town", name = "Thelsamar" },  -- era+forever
	[513] = { faction = "A", kind = "town", name = "Theramore Isle" },  -- era+forever
	[2102] = { faction = "A", kind = "inn", name = "Thunderbrew Distillery" },  -- era+forever
	[349] = { faction = "A", kind = "inn", name = "Wildhammer Keep" },  -- era+forever
	[222] = { faction = "H", kind = "town", name = "Bloodhoof Village" },  -- era+forever
	[496] = { faction = "H", kind = "hub", name = "Brackenwall Village" },  -- era+forever
	[358] = { faction = "H", kind = "start", name = "Brambleblade Ravine" },  -- era+forever
	[159] = { faction = "H", kind = "town", name = "Brill" },  -- era+forever
	[365] = { faction = "H", kind = "start", name = "Burning Blade Coven" },  -- era+forever
	[1099] = { faction = "H", kind = "town", name = "Camp Mojache" },  -- era+forever
	[221] = { faction = "H", kind = "start", name = "Camp Narache" },  -- era+forever
	[378] = { faction = "H", kind = "town", name = "Camp Taurajo" },  -- era+forever
	[154] = { faction = "H", kind = "start", name = "Deathknell" },  -- era+forever
	[251] = { faction = "H", kind = "hub", name = "Flame Crest" },  -- era+forever
	[484] = { faction = "H", kind = "town", name = "Freewind Post" },  -- era+forever
	[2119] = { faction = "H", kind = "inn", name = "Gallows' End Tavern" },  -- era+forever
	[117] = { faction = "H", kind = "town", name = "Grom'gol Base Camp" },  -- era+forever
	[321] = { faction = "H", kind = "town", name = "Hammerfall" },  -- era+forever
	[340] = { faction = "H", kind = "town", name = "Kargath" },  -- era+forever
	[155] = { faction = "H", kind = "start", name = "Night Web's Hollow" },  -- era+forever
	[362] = { faction = "H", kind = "town", name = "Razor Hill" },  -- era+forever
	[3317] = { faction = "H", kind = "town", name = "Revantusk Village" },  -- era+forever
	[2408] = { faction = "H", kind = "town", name = "Shadowprey Village" },  -- era+forever
	[431] = { faction = "H", kind = "town", name = "Splintertree Post" },  -- era+forever
	[75] = { faction = "H", kind = "town", name = "Stonard" },  -- era+forever
	[460] = { faction = "H", kind = "town", name = "Sun Rock Retreat" },  -- era+forever
	[272] = { faction = "H", kind = "town", name = "Tarren Mill" },  -- era+forever
	[2368] = { faction = "H", kind = "town", name = "Tarren Mill" },  -- era+forever
	[380] = { faction = "H", kind = "town", name = "The Crossroads" },  -- era+forever
	[364] = { faction = "H", kind = "start", name = "The Den" },  -- era+forever
	[228] = { faction = "H", kind = "town", name = "The Sepulcher" },  -- era+forever
	[363] = { faction = "H", kind = "start", name = "Valley of Trials" },  -- era+forever
	[1237] = { faction = "H", kind = "hub", name = "Valormok" },  -- era+forever
	[2897] = { faction = "H", kind = "hub", name = "Zoram'gar Outpost" },  -- era+forever
	[35] = { faction = "N", kind = "town", name = "Booty Bay" },  -- era+forever
	[3425] = { faction = "N", kind = "town", name = "Cenarion Hold" },  -- era+forever
	[2255] = { faction = "N", kind = "town", name = "Everlook" },  -- era+forever
	[16636] = { faction = "N", kind = "town", name = "Falaath Village" },  -- forever
	[976] = { faction = "N", kind = "town", name = "Gadgetzan" },  -- era+forever
	[2268] = { faction = "N", kind = "town", name = "Light's Hope Chapel" },  -- era+forever
	[541] = { faction = "N", kind = "hub", name = "Marshal's Refuge" },  -- era+forever
	[2240] = { faction = "N", kind = "hub", name = "Mirage Raceway" },  -- era+forever
	[2361] = { faction = "N", kind = "hub", name = "Nighthaven" },  -- era+forever
	[16727] = { faction = "N", kind = "town", name = "Powderfuse Port" },  -- forever
	[392] = { faction = "N", kind = "town", name = "Ratchet" },  -- era+forever
	[16624] = { faction = "N", kind = "town", name = "Shen'dar Village" },  -- forever
	[977] = { faction = "N", kind = "hub", name = "Steamwheedle Port" },  -- era+forever
	[16635] = { faction = "N", kind = "town", name = "Thendal Village" },  -- forever
	[1446] = { faction = "N", kind = "hub", name = "Thorium Point" },  -- era+forever
	[16638] = { faction = "N", kind = "town", name = "Valanaar" },  -- forever
	[16628] = { faction = "N", kind = "hub", name = "Valanaar Skydocks" },  -- forever
}

if ns.Mark then ns.Mark("Hubs") end
