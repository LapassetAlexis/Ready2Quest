-- EditMode.lua -- mode « Déplacer les cadres »
--
-- Restait dans Stats.lua jusqu'en 1.36.0 (résumé de stuff et stats du
-- portrait, retirés en 1.37.0). Les modules qui ont un cadre à placer
-- enveloppent StartEditMode / StopEditMode (Notice.lua : l'icône d'alerte).
local ADDON, ns = ...
local L = ns.L

function ns:StartEditMode()
	if self.editMode then return end
	self.editMode = true
	-- le panneau de réglages se ferme à l'entrée ; sans ce bandeau, le bouton
	-- « Terminer » disparaissait avec lui et l'édition devenait un cul-de-sac
	if self.ShowEditBanner then self:ShowEditBanner() end
	self:Print(L.MSG_EDIT_START)
	if self.RefreshOptions then self:RefreshOptions() end
end

function ns:StopEditMode()
	if not self.editMode then return end
	self.editMode = nil
	if self.HideEditBanner then self:HideEditBanner() end
	self:Print(L.MSG_EDIT_STOP)
	if self.RefreshOptions then self:RefreshOptions() end
end

function ns:ToggleEditMode()
	if self.editMode then
		self:StopEditMode()
	else
		self:StartEditMode()
	end
	return self.editMode
end

if ns.Mark then ns.Mark("EditMode") end
