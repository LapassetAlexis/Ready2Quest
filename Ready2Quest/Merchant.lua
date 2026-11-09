-- Merchant.lua -- automatismes chez le marchand, suivi par personnage
--
--   * vente automatique des objets gris (par tranches, le serveur limite)
--   * réparation automatique si le marchand répare et que l'or suffit
--   * mesure du coût de réparation, pour le check « réparation »
--   * niveau de la dernière visite chez l'entraîneur de classe
local ADDON, ns = ...
local L = ns.L

local NUM_BAG_SLOTS = 4
local SELL_BATCH = 12        -- objets vendus par passe
local SELL_PAUSE = 0.4       -- secondes entre deux passes

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

-- Données par personnage : ns:CharKey / ns:CharData, socle commun
-- (Libs/Socle/Store.lua).

-- Première connexion d'un personnage : on suppose ses sorts à jour, sinon le
-- check « sorts à apprendre » crierait dès l'installation.
function ns:InitCharacterTracking()
	local data = self:CharData()
	if data.trainerLevel == nil then
		data.trainerLevel = tonumber(Call(rawget(_G, "UnitLevel"), "player")) or 1
	end
end

-- ---------------------------------------------------------------------------
-- Formatage de l'argent (pièces de cuivre -> "1 po 23 pa 4 pc")
-- ---------------------------------------------------------------------------
function ns:FormatMoney(copper)
	copper = math.floor(tonumber(copper) or 0)
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local cu = copper % 100
	local parts = {}
	if gold > 0 then parts[#parts + 1] = gold .. " " .. L.MONEY_GOLD end
	if silver > 0 then parts[#parts + 1] = silver .. " " .. L.MONEY_SILVER end
	if cu > 0 or #parts == 0 then parts[#parts + 1] = cu .. " " .. L.MONEY_COPPER end
	return table.concat(parts, " ")
end

-- ---------------------------------------------------------------------------
-- Durabilité : points manquants sur tout l'équipement
-- ---------------------------------------------------------------------------
function ns:MissingDurability()
	local fn = rawget(_G, "GetInventoryItemDurability")
	if type(fn) ~= "function" then return nil end
	local missing, any = 0, false
	for slot = 1, 19 do
		local ok, current, max = pcall(fn, slot)
		if ok and type(current) == "number" and type(max) == "number" and max > 0 then
			any = true
			missing = missing + (max - current)
		end
	end
	if not any then return nil end
	return missing
end

-- Coût mesuré chez le marchand, ramené à un prix par point de durabilité :
-- c'est ce qui permet d'estimer le coût actuel sans être chez un marchand.
function ns:MeasureRepairCost()
	if type(CanMerchantRepair) ~= "function" or not Call(CanMerchantRepair) then return end
	local cost = tonumber((Call(rawget(_G, "GetRepairAllCost")))) or 0
	local missing = self:MissingDurability()
	if cost > 0 and missing and missing > 0 then
		self:CharData().repairRate = cost / missing
	end
end

function ns:EstimatedRepairCost()
	local rate = self:CharData().repairRate
	if type(rate) ~= "number" then return nil end
	local missing = self:MissingDurability()
	if not missing then return nil end
	return math.floor(rate * missing + 0.5)
end

-- ---------------------------------------------------------------------------
-- Vente automatique des gris
-- ---------------------------------------------------------------------------
local function ContainerItem(bag, slot)
	if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
		local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
		if ok and type(info) == "table" then return info end
	end
	return nil
end

local function SellPrice(info)
	if info.hasNoValue then return 0 end
	local price = select(11, ns.ItemInfo(info.hyperlink or info.itemID))
	return tonumber(price) or 0
end

local function UseItem(bag, slot)
	local fn = (C_Container and C_Container.UseContainerItem) or rawget(_G, "UseContainerItem")
	if type(fn) ~= "function" then return false end
	return pcall(fn, bag, slot)
end

-- Une passe : vend au plus SELL_BATCH objets gris. Renvoie le nombre vendu
-- et la valeur, plus true s'il en reste.
function ns:SellGrayBatch()
	local sold, value = 0, 0
	for bag = 0, NUM_BAG_SLOTS do
		local slots = C_Container and Call(C_Container.GetContainerNumSlots, bag)
		for slot = 1, tonumber(slots) or 0 do
			local info = ContainerItem(bag, slot)
			if info and info.quality == 0 and not info.isLocked then
				local price = SellPrice(info)
				if price > 0 then
					if sold >= SELL_BATCH then return sold, value, true end
					if UseItem(bag, slot) then
						sold = sold + 1
						value = value + price * (info.stackCount or 1)
					end
				end
			end
		end
	end
	return sold, value, false
end

function ns:RunAutoSell()
	local run = self.sellRun
	if not run or not self.merchantOpen then self.sellRun = nil; return end
	local sold, value, more = self:SellGrayBatch()
	run.count = run.count + sold
	run.value = run.value + value
	if more and sold > 0 and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(SELL_PAUSE, function() ns:RunAutoSell() end)
		return
	end
	self.sellRun = nil
	if run.count > 0 then
		self:Print(self:FP("MSG_SOLD", run.count, self:FormatMoney(run.value)))
	end
end

-- ---------------------------------------------------------------------------
-- Réparation automatique
-- ---------------------------------------------------------------------------
function ns:AutoRepair()
	if type(CanMerchantRepair) ~= "function" or not Call(CanMerchantRepair) then return end
	local cost, canRepair = Call(rawget(_G, "GetRepairAllCost"))
	cost = tonumber(cost) or 0
	if cost <= 0 or canRepair == false then return end
	local money = tonumber(Call(rawget(_G, "GetMoney"))) or 0
	if money < cost then
		return self:Print(self:F("MSG_REPAIR_POOR", self:FormatMoney(cost)))
	end
	if type(RepairAllItems) ~= "function" then return end
	if pcall(RepairAllItems) then
		self:Print(self:F("MSG_REPAIRED", self:FormatMoney(cost)))
	end
end

function ns:OnMerchantShow()
	local db = self:DB()
	self.merchantOpen = true
	self:MeasureRepairCost()
	if db.enabled == false then return end
	if db.autoRepair ~= false then self:AutoRepair() end
	-- la première fois, on dit ce qu'on fait : un gris qu'on voulait garder
	-- ne doit pas disparaître sans explication
	if db.autoSellGray ~= false and not db.autoSellNoticed then
		db.autoSellNoticed = true
		self:Print(L.MSG_AUTOSELL_NOTICE)
	end
	if db.autoSellGray ~= false and not self.sellRun then
		self.sellRun = { count = 0, value = 0 }
		self:RunAutoSell()
	end
end

function ns:OnMerchantClosed()
	self.merchantOpen = false
	if self.sellRun and self.sellRun.count > 0 then
		self:Print(self:FP("MSG_SOLD", self.sellRun.count, self:FormatMoney(self.sellRun.value)))
	end
	self.sellRun = nil
end

-- ---------------------------------------------------------------------------
-- Entraîneur : seul l'entraîneur de classe compte (pas les métiers)
-- ---------------------------------------------------------------------------
function ns:OnTrainerShow()
	local isTradeskill = rawget(_G, "IsTradeskillTrainer")
	if type(isTradeskill) == "function" and Call(isTradeskill) then return end
	local level = tonumber(Call(rawget(_G, "UnitLevel"), "player"))
	if level then self:CharData().trainerLevel = level end
end

if ns.Mark then ns.Mark("Merchant") end
