------------------------------------------------------------
-- Hoard by Sonaza

local ADDON_NAME, SHARED = ...;
local _;

local Addon, DATA, ENUM = unpack(SHARED);

local LibQTip = LibStub("LibQTip-1.0");
local AceDB = LibStub("AceDB-3.0");

local CONNECTED_REALM, HOME_REALM, PLAYER_FACTION, PLAYER_NAME;

local ICON_ARROW_PROFIT  = "Interface\\AddOns\\Hoard\\media\\profit_arrow.tga";
local ICON_ARROW_LOSS    = "Interface\\AddOns\\Hoard\\media\\loss_arrow.tga";
local ICON_MAIL          = "Interface\\AddOns\\Hoard\\media\\mail_icon.tga";

local TEX_ARROW_PROFIT   = DATA.ICON_PATTERN_12:format(ICON_ARROW_PROFIT);
local TEX_ARROW_LOSS     = DATA.ICON_PATTERN_12:format(ICON_ARROW_LOSS);
local TEX_MAIL_ICON      = DATA.ICON_PATTERN_12:format(ICON_MAIL);

---------------------------------------------------

local module = {};
Addon:RegisterModule("gold", module);

module.name = "Hoard Gold";
module.settings = {
	type = "data source",
	label = "Hoard Gold",
	text = "",
	icon = DATA.ICON_ADDON,
	OnClick = function(frame, button)
		module:OnClick(frame, button);
	end,
	OnEnter = function(frame)
		if(module.tooltipOpen) then return end
		module.tooltipOpen = true;
		
		module.tooltip = LibQTip:Acquire("HoardGoldTooltip", 2, "LEFT", "RIGHT");
		module:OnEnter(frame, module.tooltip);
	end,
	OnLeave = function(frame)
		module:OnLeave(frame, module.tooltip);
		module.tooltipOpen = false;
		
		if(module.tooltip) then
			LibQTip:Release(module.tooltip);
			module.tooltip = nil;
		end
	end,
};

---------------------------------------------------
-- Module methods

function module:Initialize()
	Addon:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
	Addon:RegisterEvent("PLAYER_MONEY");
	
	Addon:RegisterEvent("MAIL_SHOW");
	Addon:RegisterEvent("MAIL_INBOX_UPDATE");
	
	module.session = {
		gained = 0,
		lost = 0,
		total = 0,
	};
	
	module.mailmoney = 0;
	module.mailmoneybuffer = 0;
	
	CONNECTED_REALM, HOME_REALM, PLAYER_FACTION, PLAYER_NAME = Addon:GetPlayerInformation();
	
	Addon:PLAYER_MONEY();
end

function module:OnClick(frame, button)
	if(button == "RightButton") then
		if(module.tooltip) then
			module.tooltip:Hide();
		end
		Addon:OpenContextMenu(frame, module:GetContextMenuData());
	end
end

function module:OnEnter(frame, tooltip)
	tooltip:Clear();
	tooltip:SetClampedToScreen(true);
	
	tooltip:AddHeader(DATA.TEX_ADDON_ICON .. " |cffffdd00Hoard Gold|r")
	
	tooltip:AddLine("|cffffdd00Session|r", string.format("|cff%s%s|r", Addon:GetTotalColorHex(module.session.total), module:GetCorrectCoinString(module.session.total)));
	tooltip:AddLine(TEX_ARROW_PROFIT .. " Profit", module:GetCorrectCoinString(module.session.gained));
	tooltip:AddLine(TEX_ARROW_LOSS .. " Loss", module:GetCorrectCoinString(module.session.lost));
	tooltip:AddLine(" ")
	
	if(PLAYER_FACTION ~= "Neutral") then
		local history = module:GetMoneyHistory();
		
		if(Addon.db.global.showToday) then
			tooltip:AddLine("|cffffdd00Today|r", string.format("|cff%s%s|r", Addon:GetTotalColorHex(history.today.total), module:GetCorrectCoinString(history.today.total)));
			
			if(not Addon.db.global.onlyHistoryTotals) then
				tooltip:AddLine(TEX_ARROW_PROFIT .. " Profit", module:GetCorrectCoinString(history.today.gained));
				tooltip:AddLine(TEX_ARROW_LOSS .. " Loss", module:GetCorrectCoinString(history.today.lost));
				tooltip:AddLine(" ");
			end
		end
		
		if(Addon.db.global.showYesterday) then
			tooltip:AddLine("|cffffdd00Yesterday|r", string.format("|cff%s%s|r", Addon:GetTotalColorHex(history.yesterday.total), module:GetCorrectCoinString(history.yesterday.total)));
			
			if(not Addon.db.global.onlyHistoryTotals) then
				tooltip:AddLine(TEX_ARROW_PROFIT .. " Profit", module:GetCorrectCoinString(history.yesterday.gained));
				tooltip:AddLine(TEX_ARROW_LOSS .. " Loss", module:GetCorrectCoinString(history.yesterday.lost));
				tooltip:AddLine(" ");
			end
		end
		
		if(Addon.db.global.showWeek) then
			tooltip:AddLine("|cffffdd00Past Week|r", string.format("|cff%s%s|r", Addon:GetTotalColorHex(history.week_total.total), module:GetCorrectCoinString(history.week_total.total)));
			
			if(not Addon.db.global.onlyHistoryTotals) then
				tooltip:AddLine(TEX_ARROW_PROFIT .. " Profit", module:GetCorrectCoinString(history.week_total.gained));
				tooltip:AddLine(TEX_ARROW_LOSS .. " Loss", module:GetCorrectCoinString(history.week_total.lost));
				tooltip:AddLine(" ");
			end
		end
		
		if(Addon.db.global.onlyHistoryTotals) then tooltip:AddLine(" "); end
	else
		tooltip:AddLine("Choose faction to view gold history");
		tooltip:AddLine(" ");
	end
	
	local shouldShowBothFactions = Addon.db.global.bothFactionsTooltip and PLAYER_FACTION ~= "Neutral";
	
	module:ListFactionOnTooltip(tooltip, PLAYER_FACTION, shouldShowBothFactions);
	
	if(shouldShowBothFactions) then
		local otherFaction = Addon:GetOtherFactionName();
		module:ListFactionOnTooltip(tooltip, otherFaction, true, true);
	end
	
	if(Addon.db.global.displayHint) then
		tooltip:AddLine(" ");
		tooltip:AddLine("|cffffdd00Right-Click|r", "|cffffffffOpen options menu|r");
	end
	
	tooltip:SetAutoHideDelay(0.01, frame);
	
	local point, relative = Addon:GetAnchors(frame);
	tooltip:ClearAllPoints();
	tooltip:SetPoint(point, frame, relative, 0, 0);
	
	tooltip:Show();
end

function module:ListFactionOnTooltip(tooltip, faction, withTitles, useSpacerBefore)
	if(not tooltip) then return end
	
	faction = faction or PLAYER_FACTION;
	withTitles = withTitles or false;
	
	local factionColor = Addon:GetFactionColor(faction);
	
	local characters = Addon:GetCharacterData(faction);
	local totalGold = 0;
	
	local list_characters = {};
	for name, data in pairs(characters) do
		table.insert(list_characters, {name = name, data = data});
		totalGold = totalGold + data.gold + data.inMail;
	end
	
	if(#list_characters == 0) then return end
	
	table.sort(list_characters, function(a, b)
		if(a == nil and b == nil) then return false end
		if(a == nil) then return true end
		if(b == nil) then return false end
		
		return (a.data.gold + a.data.inMail) > (b.data.gold + b.data.inMail);
	end);
	
	if(withTitles) then
		if(useSpacerBefore) then tooltip:AddLine(" "); end
		
		tooltip:AddLine(("|cff%s%s|r"):format(factionColor, faction));
		tooltip:AddSeparator();
	end
	
	for k, data in ipairs(list_characters) do
		module:SetTooltip(tooltip, data.name, data.data);
	end
	
	if(#list_characters > 1) then
		tooltip:AddLine(" ");
		if(withTitles) then
			tooltip:AddLine(("|cffffdd00Total (|cff%s%s|cffffdd00)|r"):format(factionColor, faction), module:GetCorrectCoinString(totalGold));
		else
			tooltip:AddLine("|cffffdd00Total|r", module:GetCorrectCoinString(totalGold));
		end
	end
end

function module:OnLeave(frame)
	
end

function module:GetContextMenuData()
	local colorBlindModeEnabled = (GetCVar("colorblindMode") == "1");
	local colorBlindModeText = colorBlindModeEnabled and " |cff00ff00(UI Colorblind Mode Enabled)|r" or "";
	
	local contextMenuData = {
		{
			text = DATA.TEX_ADDON_ICON .. " Hoard Gold Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Display character gold",
			func = function() Addon.db.global.displayMode = ENUM.DISPLAY_PLAYER_GOLD; module:Update(); end,
			checked = function() return Addon.db.global.displayMode == ENUM.DISPLAY_PLAYER_GOLD; end,
		},
		{
			text = "Display total realm gold",
			func = function() Addon.db.global.displayMode = ENUM.DISPLAY_REALM_GOLD; module:Update(); end,
			checked = function() return Addon.db.global.displayMode == ENUM.DISPLAY_REALM_GOLD; end,
		},
		{
			text = "|cffffffffDisplay values using letters|r" .. colorBlindModeText,
			func = function() Addon.db.global.literalEnabled = not Addon.db.global.literalEnabled; module:Update(); end,
			checked = function() return Addon.db.global.literalEnabled or colorBlindModeEnabled; end,
			isNotRadio = true,
			disabled = colorBlindModeEnabled,
		},
		{
			text = "Shortened display",
			func = function() Addon.db.global.shortDisplay = not Addon.db.global.shortDisplay; module:Update(); end,
			checked = function() return Addon.db.global.shortDisplay; end,
			isNotRadio = true,
		},
		{
			text = "Only show gold",
			func = function() Addon.db.global.onlyGold = not Addon.db.global.onlyGold; module:Update(); end,
			checked = function() return Addon.db.global.onlyGold; end,
			isNotRadio = true,
		},
		{
			text = "Gold icon on the left",
			func = function() Addon.db.global.goldLeftSide = not Addon.db.global.goldLeftSide; module:Update(); end,
			checked = function() return Addon.db.global.goldLeftSide; end,
			isNotRadio = true,
		},
		{
			text = "Show both factions on the tooltip",
			func = function() Addon.db.global.bothFactionsTooltip = not Addon.db.global.bothFactionsTooltip; module:Update(); end,
			checked = function() return Addon.db.global.bothFactionsTooltip; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "History Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Show today",
			func = function() Addon.db.global.showToday = not Addon.db.global.showToday; end,
			checked = function() return Addon.db.global.showToday; end,
			isNotRadio = true,
		},
		{
			text = "Show yesterday",
			func = function() Addon.db.global.showYesterday = not Addon.db.global.showYesterday; end,
			checked = function() return Addon.db.global.showYesterday; end,
			isNotRadio = true,
		},
		{
			text = "Show past week",
			func = function() Addon.db.global.showWeek = not Addon.db.global.showWeek; end,
			checked = function() return Addon.db.global.showWeek; end,
			isNotRadio = true,
		},
		{
			text = "Only display totals",
			func = function() Addon.db.global.onlyHistoryTotals = not Addon.db.global.onlyHistoryTotals; end,
			checked = function() return Addon.db.global.onlyHistoryTotals; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Miscellaneous", isTitle = true, notCheckable = true,
		},
		{
			text = "Reset current session",
			func = function()
				module.session = {
					gained = 0,
					lost = 0,
					total = 0,
				};
			end,
			notCheckable = true,
		},
		{
			text = "Reset history for today",
			func = function() module:ResetHistory(0); end,
			notCheckable = true,
		},
		{
			text = "Reset history for yesterday",
			func = function() module:ResetHistory(-1); end,
			notCheckable = true,
		},
		{
			text = "Remove characters",
			menuList = Addon:GetCharacterRemovalMenu(),
			hasArrow = true,
			notCheckable = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Display tooltip hint",
			func = function() Addon.db.global.displayHint = not Addon.db.global.displayHint; end,
			checked = function() return Addon.db.global.displayHint; end,
			isNotRadio = true,
		},
		{
			text = "Close",
			func = function() CloseMenus(); end,
			notCheckable = true,
		},
	};
	
	return contextMenuData;
end

function module:GetText()
	local displayGold = 0;
	
	if(Addon.db.global.displayMode == ENUM.DISPLAY_PLAYER_GOLD) then
		displayGold = module:GetPlayerGold();
	elseif(Addon.db.global.displayMode == ENUM.DISPLAY_REALM_GOLD) then
		displayGold = module:GetRealmGold();
	end
	
	if(Addon.db.global.onlyGold and displayGold >= 10000) then
		displayGold = displayGold - (displayGold % 10000);
	end
	
	local useLiteralMode = Addon.db.global.literalEnabled or GetCVar("colorblindMode") == "1";
	
	if(Addon.db.global.shortDisplay) then
		return module:GetShortCoinString(displayGold, useLiteralMode);
	else
		return module:GetMultiCoinString(displayGold);
	end
end

function module:GetMultiCoinString(coins)
	local useLiteralMode = Addon.db.global.literalEnabled or GetCVar("colorblindMode") == "1";
	if(useLiteralMode) then
		return module:GetLiteralCoinString(coins);
	else
		return module:GetCoinTextureString(coins);
	end
end

---------------------------------------------------
-- Utility methods used by module

function module:AddMoneyRecord(money_diff)
	if(money_diff == nil or money_diff == 0) then return end
	if(PLAYER_FACTION == "Neutral") then return end
	
	local date = Addon:GetDate();
	local statsData = Addon:GetStatsData();
	
	if(money_diff > 0) then
		statsData[date].gained = statsData[date].gained + money_diff;
		module.session.gained = module.session.gained + money_diff;
	elseif(money_diff < 0) then
		statsData[date].lost = statsData[date].lost + math.abs(money_diff);
		module.session.lost = module.session.lost + math.abs(money_diff);
	end
	
	module.session.total = module.session.gained - module.session.lost;
end

function module:ResetHistory(offset)
	if(not offset or offset > 0) then return end
	
	local thedate = Addon:GetDate(offset);
	local statsData = Addon:GetStatsData();
	statsData[thedate] = {
		gained = 0,
		lost = 0,
	};
end

function module:GetMoneyHistory()
	local today 	= Addon:GetDate();
	local yesterday = Addon:GetDate(-1);
	local week_ago 	= Addon:GetDate(-7);
	
	local statsData = Addon:GetStatsData();
	local archive = Addon:GetArchive();
	
	local resultData = {
		today 		= {
			gained	= statsData[today].gained,
			lost	= statsData[today].lost,
		},
		yesterday	= {
			gained	= statsData[yesterday].gained,
			lost	= statsData[yesterday].lost,
		},
		week_total	= {
			gained 	= 0,
			lost 	= 0,
		},
	};
	
	for date, data in pairs(statsData) do
		if(date >= week_ago) then
			resultData.week_total.gained = resultData.week_total.gained + data.gained;
			resultData.week_total.lost 	 = resultData.week_total.lost + data.lost;
		else
			archive[date] = statsData[date];
			statsData[date] = nil;
		end
	end
	
	resultData.today.total 		= resultData.today.gained - resultData.today.lost;
	resultData.yesterday.total 	= resultData.yesterday.gained - resultData.yesterday.lost;
	resultData.week_total.total = resultData.week_total.gained - resultData.week_total.lost;
	
	return resultData;
end


function module:GetPlayerGold()
	local playerData = Addon:GetPlayerData();
	return playerData.gold, playerData.inMail;
end

function module:GetRealmGold()
	local characters = Addon:GetCharacterData();
	local totalGold = 0;
	for name, data in pairs(characters) do
		if(data.gold > 0 or data.inMail > 0) then
			totalGold = totalGold + data.gold + data.inMail;
		end
	end
	
	return totalGold;
end

function module:SetTooltip(tooltip, name, data)
	local name_token, realm_token = strsplit('-', name)
	if(realm_token == HOME_REALM) then
		name = name_token;
	else
		name = string.format("%s-%s", name_token, strsub(realm_token, 0, 3));
	end
	
	local color = Addon:GetClassColor(data.class);
	
	local mail_icon = "";
	if(data.inMail and data.inMail > 0) then
		mail_icon = " " .. TEX_MAIL_ICON;
	end
	
	tooltip:AddLine(
		string.format("%s%s", string.format(color, name), mail_icon),
		module:GetCorrectCoinString(data.gold + data.inMail)
	);
end

function module:GetTotalColor(total)
	if(total == nil) then return 1, 0, 1 end
	
	if(total > 0) then
		return 0.647, 0.918, 0.063;
	elseif(total < 0) then
		return 0.953, 0.212, 0.212;
	end
	
	return 1, 1, 1;
end

function Addon:GetTotalColorHex(total)
	local r, g, b = module:GetTotalColor(total);
	return string.format("%x%x%x", r * 255, g * 255, b * 255)
end

function module:NormalizeCoinValue(coin)
	if(coin == nil) then return 0 end
	coin = tonumber(coin) or 0;
	return math.abs(coin), coin >= 0 and 1 or -1;
end

function module:GetCorrectCoinString(coin)
	local coin, sign = module:NormalizeCoinValue(coin)
	
	local prefix = "";
	if(sign == -1) then prefix = "-" end
	
	local useLiteralMode = Addon.db.global.literalEnabled or GetCVar("colorblindMode") == "1";
	
	if(useLiteralMode) then
		return prefix .. module:GetLiteralCoinString(coin);
	end
	
	return prefix .. strtrim(module:GetCoinTextureString(coin)) .. "  ";
end

function module:GetLiteralCoinString(coin)
	local coin, sign = module:NormalizeCoinValue(coin)
	
	local copper = coin % 100;
	local silver = math.floor((coin % 10000) / 100);
	local gold 	 = math.floor(coin / 10000);
	
	local GOLD 	 = "%s|cfff0c80bg|r ";
	local SILVER = "%d|cffc7c7c7s|r ";
	local COPPER = "%d|cffe67f35c|r";
	
	local result = "";
	
	if(gold > 0) then
		result = string.format("%s%s", result, GOLD:format(BreakUpLargeNumbers(gold)));
	end
	
	if(silver > 0) then
		result = string.format("%s%s", result, SILVER:format(silver));
	end
	
	if(copper > 0 or (gold == 0 and silver == 0)) then
		result = string.format("%s%s", result, COPPER:format(copper));
	end
	
	return strtrim(result);
end

function module:GetCoinTextureStringPatterns()
	if(not Addon.db.global.goldLeftSide) then
		return "%s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t",
		       "%d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t",
		       "%d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
	else
		return "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t %s",
		       "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t %d",
		       "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t %d"
	end
end

function module:GetCoinTextureString(coin)
	local coin, sign = module:NormalizeCoinValue(coin)
	
	local copper = coin % 100;
	local silver = math.floor((coin % 10000) / 100);
	local gold 	 = math.floor(coin / 10000);
	
	local GOLD, SILVER, COPPER = module:GetCoinTextureStringPatterns();
	
	local result = "";
	
	if(gold > 0) then
		result = string.format("%s%s ", result, GOLD:format(BreakUpLargeNumbers(gold)));
	end
	
	if(silver > 0) then
		result = string.format("%s%s ", result, SILVER:format(silver));
	end
	
	if(copper > 0 or (gold == 0 and silver == 0)) then
		result = string.format("%s%s", result, COPPER:format(copper));
	end
	
	return strtrim(result);
end

local function roundnum(num)
	return tonumber(string.format("%d", num));
end

local function roundfloat(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

function module:GetShortCoinString(coin, literal)
	if(literal == nil) then literal = false end
	
	local coin, sign = module:NormalizeCoinValue(coin)
	
	local copper = coin % 100;
	local silver = math.floor((coin % 10000) / 100);
	local gold 	 = math.floor(coin / 10000);
	
	local GOLD 	 = "%s%s|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t";
	local SILVER = "%d|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t";
	local COPPER = "%d|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t";
	
	if(literal) then
		GOLD   = "|cffffffff%s%s|r|cfff0c80bg|r ";
		SILVER = "|cffffffff%d|r|cffc7c7c7s|r ";
		COPPER = "|cffffffff%d|r|cffd0a688c|r";
	end
	
	if(gold > 0) then
		if(gold >= 1000000) then
			return GOLD:format(tostring(roundfloat(gold / 1000000, 1)), "m");
		elseif(gold >= 1000) then
			return GOLD:format(tostring(roundfloat(gold / 1000, 1)), "k");
		end
		return GOLD:format(tostring(gold), "");
	elseif(silver > 0) then
		return SILVER:format(silver);
	else
		return COPPER:format(copper);
	end
end

function module:FixName(name)
	local name, realm = strsplit("-", name, 2);
	return string.format("%s-%s", name, realm or GetRealmName());
end

function module:IsOwnCharacter(name)
	if(not name) then return false end
	
	name = module:FixName(name);
	
	local characters = Addon:GetCharacterData();
	if(characters[name].gold ~= -1) then
		return true, characters[name];
	else
		characters[name] = nil;
	end
	
	return false;
end

---------------------------------------------------
-- Events used by the module

function Addon:NEUTRAL_FACTION_SELECT_RESULT()
	local newFaction = UnitFactionGroup("player");
	
	local characterData = Addon:GetCharacterData();
	local newCharacterData = Addon:GetCharacterData(newFaction);
	
	newCharacterData[PLAYER_NAME] = {
		gold = characterData[PLAYER_NAME].gold,
		class = characterData[PLAYER_NAME].class,
		inMail = characterData[PLAYER_NAME].inMail,	-- Should definitely be 0/nil if player was pandaren but copying it anyway
	};
	
	-- Remove character's entry in neutral faction
	characterData[PLAYER_NAME] = nil;
	
	PLAYER_FACTION = newFaction;
	
	-- Money sort of appeared from nowhere when character chose faction so let's record it
	module:AddMoneyRecord(newCharacterData[PLAYER_NAME].gold);
end

function Addon:PLAYER_MONEY()
	local playerData = Addon:GetPlayerData();
	local playerMoney = GetMoney();
	
	if(playerData.gold >= 0) then
		local diff = playerMoney - playerData.gold;
		
		if(diff > 0 and playerData.inMail > 0 and module.mailmoneybuffer > 0) then
			diff = diff - module.mailmoneybuffer;
			module.mailmoneybuffer = 0;
		elseif(diff < 0 and module.sentToAlt) then
			diff = 0;
			module.sentToAlt = false;
		end
		
		module:AddMoneyRecord(diff);
	end
	
	playerData.gold = playerMoney;
	
	module:Update();
end

function Addon:MAIL_SHOW()
	
end

function Addon:MAIL_INBOX_UPDATE()
	module:UpdateMail();
end

function module:UpdateMail()
	local mailmoney = 0;
	
	local inboxNum = GetInboxNumItems();
	if(inboxNum > 0) then
		for index = 1, inboxNum do
			local _, _, sender, _, money = GetInboxHeaderInfo(index);
			if(module:IsOwnCharacter(sender) and money > 0) then
				mailmoney = mailmoney + money;
			end
		end
	end
	
	local playerData = Addon:GetPlayerData();
	playerData.inMail = mailmoney;
end

hooksecurefunc("SetSendMailMoney", function(...) module:SetSendMailMoneyHook(...) end)
function module:SetSendMailMoneyHook(copper)
	module.mailmoney = copper;
end

hooksecurefunc("SendMail", function(...) module:SendMailHook(...) end)
function module:SendMailHook(recipient, subject, body)
	if(not recipient) then return end
	
	local isOwn, data = module:IsOwnCharacter(recipient);
	if(isOwn and module.mailmoney > 0) then
		module.sentToAlt = true;
		data.inMail = data.inMail + module.mailmoney;
		
		Addon:AddMessage("Sent %s to own character (%s)", module:GetMultiCoinString(module.mailmoney), Addon:GetClassColor(data.class):format(recipient))
	end
	
	module.mailmoney = 0;
end

hooksecurefunc("TakeInboxMoney", function(...) module:TakeInboxMoneyHook(...) end);
hooksecurefunc("AutoLootMailItem", function(...) module:TakeInboxMoneyHook(...) end);
function module:TakeInboxMoneyHook(index)
	local _, _, sender, _, money = GetInboxHeaderInfo(index);
	if(module:IsOwnCharacter(sender) and money > 0) then
		module.mailmoneybuffer = money;
	end
end
