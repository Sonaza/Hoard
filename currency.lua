------------------------------------------------------------
-- Hoard by Sonaza

local ADDON_NAME, SHARED = ...;
local _;

local Addon, DATA, ENUM = unpack(SHARED);

local LibQTip = LibStub("LibQTip-1.0");
local AceDB = LibStub("AceDB-3.0");

local CONNECTED_REALM, HOME_REALM, PLAYER_FACTION, PLAYER_NAME;

local MODULE_ICON       = "Interface\\Icons\\Ability_Fomor_Boss_Rune_Yellow";
local TEX_MODULE_ICON   = DATA.ICON_PATTERN_12:format(MODULE_ICON);

local ICON_ARROW_PROFIT = "Interface\\AddOns\\Hoard\\media\\profit_arrow.tga";
local ICON_ARROW_LOSS   = "Interface\\AddOns\\Hoard\\media\\loss_arrow.tga";
local ICON_MAIL         = "Interface\\AddOns\\Hoard\\media\\mail_icon.tga";

local TEX_ARROW_PROFIT  = DATA.ICON_PATTERN_12:format(ICON_ARROW_PROFIT);
local TEX_ARROW_LOSS    = DATA.ICON_PATTERN_12:format(ICON_ARROW_LOSS);
local TEX_MAIL_ICON     = DATA.ICON_PATTERN_12:format(ICON_MAIL);

---------------------------------------------------

local module = {};
Addon:RegisterModule("currency", module);

module.name = "Hoard Currency";
module.settings = {
	type = "data source",
	label = "Hoard Currency",
	text = "",
	icon = MODULE_ICON,
	OnClick = function(frame, button)
		module:OnClick(frame, button);
	end,
	OnEnter = function(frame)
		if(module.tooltipOpen) then return end
		module.tooltipOpen = true;
		
		module.tooltip = LibQTip:Acquire("HoardCurrencyTooltip", 2, "LEFT", "RIGHT");
		module.tooltip:SetFrameStrata("TOOLTIP");
		module.tooltip:EnableMouse(true);
		module:OnEnter(frame, module.tooltip);
	end,
	OnLeave = function(frame)
		module:OnLeave(frame, module.tooltip);
		module.tooltipOpen = false;
		
		-- if(module.tooltip) then
		-- 	LibQTip:Release(module.tooltip);
		-- 	module.tooltip = nil;
		-- end
	end,
};

---------------------------------------------------
-- Module methods

function module:Initialize()
	Addon:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
	Addon:RegisterEvent("ZONE_CHANGED");
	Addon:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED");
	
	CONNECTED_REALM, HOME_REALM, PLAYER_FACTION, PLAYER_NAME = Addon:GetPlayerInformation();
	module:SaveCharacterCurrencies();
end

function module:OnClick(frame, button)
	if(button == "LeftButton") then
		securecall("ToggleCharacter", "TokenFrame");
		
	elseif(button == "RightButton") then
		module.tooltip:Hide();
		Addon:OpenContextMenu(frame, module:GetContextMenuData());
	end
end

function module:SaveCharacterCurrencies()
	local characterData = Addon:GetPlayerData();
	
	characterData.currencies = {};
	
	Addon:ExpandCurrencies();
	
	local numCurrencies = GetCurrencyListSize();
	
	for index = 1, numCurrencies do
		local name, isHeader, isExpanded, isUnused, _, count, icon, maximum, hasWeeklyLimit, currentWeeklyAmount = GetCurrencyListInfo(index);
		
		if(not isHeader) then
			local currencyID = Addon:GetCurrencyID(index);
			characterData.currencies[currencyID] = count;
		end
	end
	
	Addon:RestoreCurrencies();
end

function module:BuildCurrencyListTooltip(index, parent, tooltip)
	local currencyID = Addon:GetCurrencyID(index);
	local name, amount, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(currencyID);
	
	tooltip:AddHeader(string.format("%s |cffffdd00%s|r", DATA.ICON_PATTERN_14:format(icon), name));
	
	local characters = Addon:GetCharacterData();
	
	local total_amount = 0;
	
	local list_characters = {};
	for name, data in pairs(characters) do
		if(data.currencies and data.currencies[currencyID]) then
			table.insert(list_characters, {
				name = name,
				class = data.class,
				amount = data.currencies[currencyID],
			});
			
			total_amount = total_amount + data.currencies[currencyID];
		end
	end
	
	table.sort(list_characters, function(a, b)
		if(a == nil and b == nil) then return false end
		if(a == nil) then return true end
		if(b == nil) then return false end
		
		return a.amount > b.amount;
	end);
	
	for k, data in ipairs(list_characters) do
		local name = data.name;
		local name_token, realm_token = strsplit('-', name);
		if(realm_token == HOME_REALM) then
			name = name_token;
		else
			name = string.format("%s-%s", name_token, strsub(realm_token, 0, 3));
		end
		
		local color = Addon:GetClassColor(data.class);
		
		local currencyText = BreakUpLargeNumbers(data.amount);
		
		tooltip:AddLine(
			string.format(color, name),
			currencyText
		);
	end
	
	if(#list_characters > 1) then
		tooltip:AddLine(" ");
		tooltip:AddSeparator();
		tooltip:AddLine("|cffffdd00Total|r", string.format("%s  %s", BreakUpLargeNumbers(total_amount), DATA.ICON_PATTERN_16:format(icon)) );
	end
	
	local point, relative = Addon:GetHorizontalAnchors(parent);
	
	tooltip:ClearAllPoints();
	tooltip:SetPoint("TOP" .. point, parent, "TOP" .. relative);
	tooltip:SetClampedToScreen(true);
	tooltip:Show();
end

function module:OnEnter(frame, tooltip)
	tooltip:Clear();
	
	tooltip:AddHeader(TEX_MODULE_ICON .. " |cffffdd00Hoard Currency|r");
	
	local point, relative = Addon:GetAnchors(frame);
	
	local numCurrencies = GetCurrencyListSize();
	
	for index = 1, numCurrencies do
		local name, isHeader, isExpanded, isUnused, isWatched, count, icon, maximum, hasWeeklyLimit, currentWeeklyAmount, unknown = GetCurrencyListInfo(index);
		
		if(isUnused and Addon.db.global.hideUnused) then break end
		
		if(isHeader) then
			if(not Addon.db.global.compactCurrencies) then 
				tooltip:AddLine(" ");
				
				local lineIndex = tooltip:AddLine("|cffffdd00" .. name .. "|r", isExpanded and "" or "+");
				
				tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
					ExpandCurrencyList(index, isExpanded and 0 or 1);
					module:OnEnter(frame, module.tooltip);
				end);
				
				if(isExpanded) then
					tooltip:AddSeparator();
				end
			end
		else
			local fullColor = "";
			if(count == maximum and maximum ~= 0) then
				fullColor = "|cffff8624";
			end
			
			local lineIndex = tooltip:AddLine(
				string.format("|cfffffacd%s|r", name),
				string.format("%s%s|r  %s", fullColor, BreakUpLargeNumbers(count), DATA.ICON_PATTERN_16:format(icon))
			);
			
			tooltip:SetLineScript(lineIndex, "OnEnter", function(self)
				if(Addon.db.global.showCurrencyTip) then
					GameTooltip:SetOwner(tooltip, "ANCHOR_NONE");
					GameTooltip:SetPoint(point, tooltip, relative, 0, 0);
					GameTooltip:SetCurrencyToken(index);
					GameTooltip:AddLine(" ");
					
					if(not isUnused) then
						GameTooltip:AddLine("|cff00ff00Shift Right-Click to mark as unused|r");
					else
						GameTooltip:AddLine("|cff00ff00Shift Right-Click to remove unused|r");
					end
					
					GameTooltip:Show();
				end
				
				if(Addon.db.global.showCharacterCurrencies) then
					self.currencyListTip = LibQTip:Acquire("HoardCurrencySubTooltip", 2, "LEFT", "RIGHT");
					module:BuildCurrencyListTooltip(index, tooltip, self.currencyListTip);
				end
			end);
			
			tooltip:SetLineScript(lineIndex, "OnLeave", function(self)
				if(Addon.db.global.showCurrencyTip) then
					GameTooltip:Hide();
				end
				
				if(Addon.db.global.showCharacterCurrencies) then
					LibQTip:Release(self.currencyListTip);
					self.currencyListTip = nil;
				end
			end);
				
			tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
				if(button == "RightButton" and IsShiftKeyDown()) then
					SetCurrencyUnused(index, isUnused and 0 or 1);
					module:OnEnter(frame, module.tooltip);
				end
			end);
		end
	end
	
	if(GetCurrencyListSize() == 0) then
		tooltip:AddLine("|cffffdd00Go get some currencies!|r");
	end
	
	if(Addon.db.global.displayHint) then
		tooltip:AddLine(" ");
		tooltip:AddLine("|cffffdd00Left-Click|r", "|cffffffffOpen currency menu|r");
		tooltip:AddLine("|cffffdd00Right-Click|r", "|cffffffffOpen options menu|r");
	end
	
	tooltip:SetAutoHideDelay(0.01, frame);
	
	local point, relative = Addon:GetAnchors(frame);
	tooltip:ClearAllPoints();
	tooltip:SetPoint(point, frame, relative, 0, 0);
	
	tooltip:Show();
end

function module:OnLeave(frame, tooltip)
	
end

local expandList = {};
function Addon:ExpandCurrencies()
	expandList = {};
	
	local index = 1;
	while(GetCurrencyListInfo(index)) do
		local name, isHeader, isExpanded, isUnused, _, count, icon, maximum, hasWeeklyLimit, currentWeeklyAmount = GetCurrencyListInfo(index);
		
		if(isHeader and not isExpanded) then
			ExpandCurrencyList(index, 1);
			tinsert(expandList, name);
		end
		
		index = index + 1;
	end
end

function Addon:RestoreCurrencies()
	for _, headerName in ipairs(expandList) do
		for index = 1, GetCurrencyListSize() do
			local name, isHeader, isExpanded, isUnused, _, count, icon, maximum, hasWeeklyLimit, currentWeeklyAmount = GetCurrencyListInfo(index);
			
			if(name == headerName) then
				ExpandCurrencyList(index, 0);
				break;
			end
		end
	end
end

function module:GetCurrencyMenu(slotIndex, slotData)
	local menudata = {
		{
			text = "Slot " .. slotIndex, isTitle = true, notCheckable = true,
		},
		{
			text = "Empty the slot",
			func = function() slotData[slotIndex] = false; module:Update(); CloseMenus(); end,
			notCheckable = true,
		},
	};
	
	Addon:ExpandCurrencies();
	
	local numCurrencies = GetCurrencyListSize();
	
	for index = 1, numCurrencies do
		local name, isHeader, isExpanded, isUnused, _, count, icon, maximum, hasWeeklyLimit, currentWeeklyAmount = GetCurrencyListInfo(index);
		
		if(isUnused and Addon.db.global.hideUnused) then break end
		
		if(isHeader) then
			tinsert(menudata, {
				text = " ", isTitle = true, notCheckable = true,
			});
			tinsert(menudata, {
				text = name, isTitle = true, notCheckable = true,
			});
		else
			local currencyID = Addon:GetCurrencyID(index);
			local isWatched = Addon:IsCurrencyWatched(currencyID);
			
			tinsert(menudata, {
				text = string.format("%s %s", DATA.ICON_PATTERN_12:format(icon), name),
				func = function() slotData[slotIndex] = currencyID; module:Update(); CloseMenus(); end,
				checked = function() return isWatched; end,
				disabled = isWatched and slotData[slotIndex] ~= currencyID,
			});
		end
	end
	
	Addon:RestoreCurrencies();
	
	return menudata;
end

function module:GetContextMenuData()
	local data = Addon:GetCurrencyData();
	local playerData = Addon:GetPersonalCurrencyData();
	
	local contextMenuData = {
		{
			text = TEX_MODULE_ICON .. " Hoard Currency Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Display compact currency list",
			func = function() Addon.db.global.compactCurrencies = not Addon.db.global.compactCurrencies; end,
			checked = function() return Addon.db.global.compactCurrencies; end,
			isNotRadio = true,
		},
		{
			text = "Show currency tooltip on hover",
			func = function() Addon.db.global.showCurrencyTip = not Addon.db.global.showCurrencyTip; end,
			checked = function() return Addon.db.global.showCurrencyTip; end,
			isNotRadio = true,
		},
		{
			text = "Show character currencies on hover",
			func = function() Addon.db.global.showCharacterCurrencies = not Addon.db.global.showCharacterCurrencies; end,
			checked = function() return Addon.db.global.showCharacterCurrencies; end,
			isNotRadio = true,
		},
		{
			text = "Hide unused",
			func = function() Addon.db.global.hideUnused = not Addon.db.global.hideUnused; end,
			checked = function() return Addon.db.global.hideUnused; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Currencies", isTitle = true, notCheckable = true,
		},
		{
			text = "|cffffdd00Slot 1:|r " .. Addon:GetCurrencyString(data.watched[1]),
			hasArrow = true,
			menuList = module:GetCurrencyMenu(1, data.watched),
			notCheckable = true,
		},
		{
			text = "|cffffdd00Slot 2:|r " .. Addon:GetCurrencyString(data.watched[2]),
			hasArrow = true,
			menuList = module:GetCurrencyMenu(2, data.watched),
			notCheckable = true,
		},
		{
			text = "|cffffdd00Slot 3:|r " .. Addon:GetCurrencyString(data.watched[3]),
			hasArrow = true,
			menuList = module:GetCurrencyMenu(3, data.watched),
			notCheckable = true,
		},
		{
			text = "|cffffdd00Slot 4:|r " .. Addon:GetCurrencyString(data.watched[4]),
			hasArrow = true,
			menuList = module:GetCurrencyMenu(4, data.watched),
			notCheckable = true,
		},
		{
			text = "Use global profile",
			func = function()
				playerData.showPersonal = not playerData.showPersonal;
				if(playerData.showPersonal and playerData.watched == nil) then
					playerData.watched = {};
					for i=1,4 do
						playerData.watched[i] = data.watched[i];
					end
				end
				module:Update();
			end,
			checked = function() return not playerData.showPersonal; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Miscellaneous", isTitle = true, notCheckable = true,
		},
		{
			text = "Show dummy label if empty",
			func = function() Addon.db.global.showTextIfEmpty = not Addon.db.global.showTextIfEmpty; module:Update(); end,
			checked = function() return Addon.db.global.showTextIfEmpty; end,
			isNotRadio = true,
		},
		{
			text = "Display tooltip hint",
			func = function() Addon.db.global.displayHint = not Addon.db.global.displayHint; end,
			checked = function() return Addon.db.global.displayHint; end,
			isNotRadio = true,
		},
	};
	
	return contextMenuData;
end

function module:GetText()
	local data = Addon:GetCurrencyData();
	local text = "";
	
	for index, currencyID in ipairs(data.watched) do
		if(currencyID) then
			local name, currentAmount, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered, rarity = GetCurrencyInfo(currencyID);
			
			if(isDiscovered) then
				text = strtrim(string.format("%s %s %s", text, BreakUpLargeNumbers(currentAmount), DATA.ICON_PATTERN_12:format(icon)));
			end
		end
	end
	
	if(strlen(text) > 0) then
		return text;
	end
	
	return Addon.db.global.showTextIfEmpty and "|cffffdd00Hoard|r Currency" or "";
end

---------------------------------------------------
-- Utility methods used by module

function Addon:GetPersonalCurrencyData()
	return self.db.global.currencies.characters[PLAYER_NAME];
end

function Addon:GetCurrencyData()
	local playerData = Addon:GetPersonalCurrencyData();
	
	if(playerData.showPersonal) then
		return playerData;
	else
		return self.db.global.currencies.global;
	end
end

function Addon:IsCurrencyWatched(currency)
	local data = Addon:GetCurrencyData();
	
	for index, watchedCurrencyID in ipairs(data.watched) do
		if(watchedCurrencyID and watchedCurrencyID == currency) then
			return true;
		end
	end
	
	return false;
end

function Addon:GetCurrencyString(currencyID)
	if(not currencyID) then return "|cffd4d4d4Empty|r" end
	
	local name, amount, icon, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(currencyID);
	return string.format("%s %s", DATA.ICON_PATTERN_14:format(icon), name);
end

function Addon:GetCurrencyID(currency)
	local currencylink;
	if(type(currency) == "number") then
		currencylink = GetCurrencyListLink(currency);
	else
		currencylink = currency;
	end
	return strmatch(currencylink, "currency:(%d+)");
end

function Addon:PlayerInInstance()
	local name, instanceType = GetInstanceInfo();
	
	if(instanceType == "none" or C_Garrison.IsOnGarrisonMap()) then
		return false;
	end
	
	return true, instanceType;
end

function Addon:IsPlayerInAGroup()
	return IsInRaid() or IsInGroup();
end

---------------------------------------------------
-- Events used by the module

function Addon:CURRENCY_DISPLAY_UPDATE()
	module:Update();
	module:SaveCharacterCurrencies();
end

function Addon:ZONE_CHANGED(...)
	-- print("ZONE_CHANGED", ...);
	-- print(GetRealZoneText())
end
