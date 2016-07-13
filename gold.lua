------------------------------------------------------------
-- Hoard by Sonaza

local ADDON_NAME, SHARED = ...;
local _;

local Addon, DATA, ENUM = unpack(SHARED);

local LibDataBroker = LibStub("LibDataBroker-1.1");
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
	-- OnTooltipShow = function(tooltip)
	-- 	if not tooltip or not tooltip.AddLine then return end
	-- 	module:OnTooltipShow(tooltip);
	-- end,
	-- OnLeave = function(frame)
	-- 	module:OnLeave(frame);
	-- end,
	
	OnEnter = function(frame)
		module.tooltip = LibQTip:Acquire("HoardGoldTooltip", 2, "LEFT", "RIGHT");
		module:OnEnter(frame, module.tooltip);
	end,
	OnLeave = function(frame)
		module:OnLeave(frame, module.tooltip);
		
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
	Addon:RegisterEvent("MAIL_CLOSED");
	Addon:RegisterEvent("MAIL_INBOX_UPDATE");
	Addon:RegisterEvent("MAIL_SEND_SUCCESS");
	
	Addon.SessionData = {
		gained = 0,
		lost = 0,
		total = 0,
	};
	
	Addon.MailMoney = 0;
	Addon.MailMoneyBuffer = 0;
	
	CONNECTED_REALM, HOME_REALM, PLAYER_FACTION, PLAYER_NAME = Addon:GetPlayerInformation();
	
	Addon:PLAYER_MONEY();
end

function module:OnClick(frame, button)
	if(button == "LeftButton") then
		
	elseif(button == "RightButton") then
		module.tooltip:Hide();
		Addon:OpenContextMenu(frame, module:GetContextMenuData());
	end
end

function module:OnEnter(frame, tooltip)
	tooltip:Clear();
	
	tooltip:AddHeader(DATA.TEX_ADDON_ICON .. " |cffffdd00Hoard Gold|r")
	
	tooltip:AddLine("|cffffdd00Session|r", string.format("|cff%s%s|r", Addon:GetTotalColorHex(Addon.SessionData.total), Addon:GetCorrectCoinString(Addon.SessionData.total)));
	tooltip:AddLine(TEX_ARROW_PROFIT .. " |cffffdd00Profit|r", Addon:GetCorrectCoinString(Addon.SessionData.gained));
	tooltip:AddLine(TEX_ARROW_LOSS .. " |cffffdd00Loss|r", Addon:GetCorrectCoinString(Addon.SessionData.lost));
	tooltip:AddLine(" ")
	
	if(PLAYER_FACTION ~= "Neutral") then
		local history = Addon:GetMoneyHistory();
		
		if(Addon.db.global.showToday) then
			tooltip:AddLine("|cffffdd00Today|r", string.format("|cff%s%s|r", Addon:GetTotalColorHex(history.today.total), Addon:GetCorrectCoinString(history.today.total)));
			
			if(not Addon.db.global.onlyHistoryTotals) then
				tooltip:AddLine(TEX_ARROW_PROFIT .. " |cffffdd00Profit|r", Addon:GetCorrectCoinString(history.today.gained));
				tooltip:AddLine(TEX_ARROW_LOSS .. " |cffffdd00Loss|r", Addon:GetCorrectCoinString(history.today.lost));
				tooltip:AddLine(" ");
			end
		end
		
		if(Addon.db.global.showYesterday) then
			tooltip:AddLine("|cffffdd00Yesterday|r", string.format("|cff%s%s|r", Addon:GetTotalColorHex(history.yesterday.total), Addon:GetCorrectCoinString(history.yesterday.total)));
			
			if(not Addon.db.global.onlyHistoryTotals) then
				tooltip:AddLine(TEX_ARROW_PROFIT .. " |cffffdd00Profit|r", Addon:GetCorrectCoinString(history.yesterday.gained));
				tooltip:AddLine(TEX_ARROW_LOSS .. " |cffffdd00Loss|r", Addon:GetCorrectCoinString(history.yesterday.lost));
				tooltip:AddLine(" ");
			end
		end
		
		if(Addon.db.global.showWeek) then
			tooltip:AddLine("|cffffdd00Past Week|r", string.format("|cff%s%s|r", Addon:GetTotalColorHex(history.week_total.total), Addon:GetCorrectCoinString(history.week_total.total)));
			
			if(not Addon.db.global.onlyHistoryTotals) then
				tooltip:AddLine(TEX_ARROW_PROFIT .. " |cffffdd00Profit|r", Addon:GetCorrectCoinString(history.week_total.gained));
				tooltip:AddLine(TEX_ARROW_LOSS .. " |cffffdd00Loss|r", Addon:GetCorrectCoinString(history.week_total.lost));
				tooltip:AddLine(" ");
			end
		end
		
		if(Addon.db.global.onlyHistoryTotals) then tooltip:AddLine(" "); end
	else
		tooltip:AddLine("Choose faction to view gold history");
		tooltip:AddLine(" ");
	end
	
	do
		local characters = Addon:GetCharacterData();
		local totalGold = 0;
		
		local list_characters = {};
		for name, data in pairs(characters) do
			table.insert(list_characters, {name = name, data = data});
			totalGold = totalGold + data.gold + data.inMail;
		end
		
		table.sort(list_characters, function(Addon, b)
			if(Addon == nil and b == nil) then return false end
			if(Addon == nil) then return true end
			if(b == nil) then return false end
			
			return (Addon.data.gold + Addon.data.inMail) > (b.data.gold + b.data.inMail);
		end);
		
		for k, data in ipairs(list_characters) do
			Addon:SetTooltip(tooltip, data.name, data.data);
		end
		
		if(#list_characters > 1) then
			tooltip:AddLine(" ")
			tooltip:AddLine("|cffffdd00Total|r", Addon:GetCorrectCoinString(totalGold));
		end
	end
	
	if(Addon.db.global.displayHint) then
		tooltip:AddLine(" ")
		tooltip:AddLine("|cffffdd00Right-Click|r", "|cffffffffOpen options menu|r");
	end
	
	tooltip:SetAutoHideDelay(0.01, frame);
	
	local point, relative = Addon:GetAnchors(frame);
	tooltip:ClearAllPoints();
	tooltip:SetPoint(point, frame, relative, 0, 0);
	
	tooltip:Show();
end

function module:OnLeave(frame)
	
end

function module:GetContextMenuData()
	local characterRemovalMenuData = {};
	
	local firstFaction = true;
	local realmData = Addon:GetConnectedRealmData(false);
	for faction, factionData in pairs(realmData) do
		if(not firstFaction) then
			tinsert(characterRemovalMenuData, {
				text = " ", isTitle = true, notCheckable = true,
			});
		end
		
		tinsert(characterRemovalMenuData, {
			text = faction, isTitle = true, notCheckable = true,
		});
		firstFaction = false;
		
		for name, data in pairs(factionData.characters) do
			local name_token, realm_token = strsplit("-", name, 2);
			
			if(realm_token ~= HOME_REALM) then
				realm_token = string.format(" |cffaaaaaa(%s)|r", realm_token);
			else
				realm_token = "";
			end
			
			name_token = string.format(Addon:GetClassColor(data.class), name_token);
			
			tinsert(characterRemovalMenuData, {
				text = string.format("%s|r%s", name_token, realm_token),
				func = function() factionData.characters[name] = nil; CloseMenus(); end,
				notCheckable = true,
			});
		end
	end
	
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
			tooltip = "hai",
		},
		{
			text = "Only show gold",
			func = function() Addon.db.global.onlyGold = not Addon.db.global.onlyGold; module:Update(); end,
			checked = function() return Addon.db.global.onlyGold; end,
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
			text = "Display tooltip hint",
			func = function() Addon.db.global.displayHint = not Addon.db.global.displayHint; end,
			checked = function() return Addon.db.global.displayHint; end,
			isNotRadio = true,
		},
		{
			text = "Remove characters",
			menuList = characterRemovalMenuData,
			hasArrow = true,
			notCheckable = true,
		},
		{
			text = "Reset session",
			func = function() Addon.SessionData = { gained = 0, lost = 0, total = 0, };  end,
			notCheckable = true,
		},
	};
	
	return contextMenuData;
end

function module:GetText()
	local displayGold = 0;
	
	if(Addon.db.global.displayMode == ENUM.DISPLAY_PLAYER_GOLD) then
		displayGold = Addon:GetPlayerGold();
	elseif(Addon.db.global.displayMode == ENUM.DISPLAY_REALM_GOLD) then
		displayGold = Addon:GetRealmGold();
	end
	
	if(Addon.db.global.onlyGold and displayGold >= 10000) then
		displayGold = displayGold - (displayGold % 10000);
	end
	
	local useLiteralMode = Addon.db.global.literalEnabled or GetCVar("colorblindMode") == "1";
	
	if(Addon.db.global.shortDisplay) then
		return Addon:GetShortCoinString(displayGold, useLiteralMode);
	elseif(useLiteralMode) then
		return Addon:GetLiteralCoinString(displayGold);
	else
		return Addon:GetCoinTextureString(displayGold);
	end
end

---------------------------------------------------
-- Utility methods used by module

function Addon:AddMoneyRecord(money_diff)
	if(money_diff == nil or money_diff == 0) then return end
	if(PLAYER_FACTION == "Neutral") then return end
	
	local date = Addon:GetDate();
	local statsData = Addon:GetStatsData();
	
	if(money_diff > 0) then
		statsData[date].gained = statsData[date].gained + money_diff;
		Addon.SessionData.gained = Addon.SessionData.gained + money_diff;
	elseif(money_diff < 0) then
		statsData[date].lost = statsData[date].lost + math.abs(money_diff);
		Addon.SessionData.lost = Addon.SessionData.lost + math.abs(money_diff);
	end
	
	Addon.SessionData.total = Addon.SessionData.gained - Addon.SessionData.lost;
end

function Addon:GetMoneyHistory()
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


function Addon:GetPlayerGold()
	local playerData = Addon:GetPlayerData();
	return playerData.gold, playerData.inMail;
end

function Addon:GetRealmGold()
	local characters = Addon:GetCharacterData();
	local totalGold = 0;
	for name, data in pairs(characters) do
		if(data.gold > 0 or data.inMail > 0) then
			totalGold = totalGold + data.gold + data.inMail;
		end
	end
	
	return totalGold;
end

function Addon:SetTooltip(tooltip, name, data)
	local name_token, realm_token = strsplit('-', name)
	if(realm_token == HOME_REALM) then
		name = name_token;
	else
		name = string.format("%s-%s", name_token, strsub(realm_token, 0, 3));
	end
	
	local faction_icon = "";
	-- if(data.faction == "Alliance") then
	-- 	faction_icon = ENUM.FACTION_ICONS.Alliance;
	-- elseif(data.faction == "Horde") then
	-- 	faction_icon = ENUM.FACTION_ICONS.Horde;
	-- end
	
	local color = Addon:GetClassColor(data.class);
	
	local mail_icon = "";
	if(data.inMail > 0) then
		mail_icon = " " .. DATA.TEX_MAIL_ICON;
	end
	
	tooltip:AddLine(
		string.format("%s%s%s", faction_icon, string.format(color, name), mail_icon),
		Addon:GetCorrectCoinString(data.gold + data.inMail)
	);
end

function Addon:GetTotalColor(total)
	if(total == nil) then return 1, 0, 1 end
	
	if(total > 0) then
		return 0.647, 0.918, 0.063;
	elseif(total < 0) then
		return 0.953, 0.212, 0.212;
	end
	
	return 1, 1, 1;
end

function Addon:GetTotalColorHex(total)
	local r, g, b = Addon:GetTotalColor(total);
	return string.format("%x%x%x", r * 255, g * 255, b * 255)
end

function Addon:NormalizeCoinValue(coin)
	if(coin == nil) then return 0 end
	coin = tonumber(coin) or 0;
	return math.abs(coin), coin >= 0 and 1 or -1;
end

function Addon:GetCorrectCoinString(coin)
	local coin, sign = Addon:NormalizeCoinValue(coin)
	
	local prefix = "";
	if(sign == -1) then prefix = "-" end
	
	local useLiteralMode = Addon.db.global.literalEnabled or GetCVar("colorblindMode") == "1";
	
	if(useLiteralMode) then
		return prefix .. Addon:GetLiteralCoinString(coin);
	end
	
	return prefix .. strtrim(Addon:GetCoinTextureString(coin)) .. "  ";
end

function Addon:GetLiteralCoinString(coin)
	local coin, sign = Addon:NormalizeCoinValue(coin)
	
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

function Addon:GetCoinTextureString(coin)
	local coin, sign = Addon:NormalizeCoinValue(coin)
	
	local copper = coin % 100;
	local silver = math.floor((coin % 10000) / 100);
	local gold 	 = math.floor(coin / 10000);
	
	local GOLD 	 = "%s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t";
	local SILVER = "%d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t";
	local COPPER = "%d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t";
	
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

function Addon:GetShortCoinString(coin, literal)
	if(literal == nil) then literal = false end
	
	local coin, sign = Addon:NormalizeCoinValue(coin)
	
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

function Addon:FixName(name)
	local name_token, realm_token = strsplit("-", name, 2);
	return string.format("%s-%s", name_token, realm_token or GetRealmName());
end

function Addon:IsOwnCharacter(name)
	name = Addon:FixName(name);
	
	local characters = Addon:GetCharacterData();
	if(characters[name].gold ~= -1) then
		return true, characters[name];
	else
		characters[name] = nil;
		return false, nil;
	end
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
	Addon:AddMoneyRecord(newCharacterData[PLAYER_NAME].gold);
end

function Addon:PLAYER_MONEY()
	local playerData = Addon:GetPlayerData();
	local playerMoney = GetMoney();
	
	if(playerData.gold >= 0) then
		local diff = playerMoney - playerData.gold;
		
		if(diff > 0 and playerData.inMail > 0 and Addon.MailMoneyBuffer > 0) then
			playerData.inMail = playerData.inMail - Addon.MailMoneyBuffer;
			diff = diff - Addon.MailMoneyBuffer;
			Addon.MailMoneyBuffer = 0;
		elseif(diff < 0 and Addon.MoneySentToAlt) then
			diff = 0;
			Addon.MoneySentToAlt = false;
		end
		
		Addon:AddMoneyRecord(diff);
	end
	
	playerData.gold = playerMoney;
	
	module:Update();
end

function Addon:MAIL_SHOW()
	Addon.MailOpen = true;
	Addon.MailRescan = true;
	
	if(not Addon.MailHooked) then
		hooksecurefunc("SetSendMailMoney", function(amount)
			Addon.MailMoney = amount;
		end);
		
		hooksecurefunc("TakeInboxMoney", function(index)
			local mail = Addon.MailCache[index];
			if(Addon:IsOwnCharacter(mail.sender) and mail.money > 0) then
				Addon.MailMoneyBuffer = mail.money;
			end
		end);

		hooksecurefunc("AutoLootMailItem", function(index)
			local mail = Addon.MailCache[index];
			if(Addon:IsOwnCharacter(mail.sender) and mail.money > 0) then
				Addon.MailMoneyBuffer = mail.money;
			end
		end);
		
		Addon.MailHooked = true;
	end
end

function Addon:MAIL_CLOSED()
	Addon.MailOpen = false;
	Addon.MailRescan = true;
end

function Addon:MAIL_INBOX_UPDATE()
	if(not Addon.MailOpen) then return end
	
	Addon.MailCache = {};
	
	local inboxNum = GetInboxNumItems();
	if(inboxNum > 0) then
		local mailMoney = 0;
		
		for mail_index = 1, inboxNum do
			local _, _, sender, _, money = GetInboxHeaderInfo(mail_index);
			
			Addon.MailCache[mail_index] = {
				sender = sender,
				money = money,
			};
		end
		
		module:Update();
	end
end

function Addon:MAIL_SEND_SUCCESS()
	local recipient = strtrim(SendMailNameEditBox:GetText());
	recipient = Addon:FixName(recipient);
	
	local isOwn, characterData = Addon:IsOwnCharacter(recipient);
	if(isOwn) then
		Addon.MoneySentToAlt = true;
		characterData.inMail = characterData.inMail + Addon.MailMoney;
	end
	
	Addon.MailMoney = 0;
end
