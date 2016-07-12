------------------------------------------------------------
-- Hoard by Sonaza

local ADDON_NAME, SHARED = ...;

local _G = getfenv(0);

local LibStub = LibStub;
local A = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0");
_G[ADDON_NAME] = A;
SHARED[1] = A;

local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local AceDB = LibStub("AceDB-3.0")

local ICON_ADDON 		= "Interface\\Icons\\INV_misc_phoenixegg";
local ICON_ARROW_PROFIT	= "Interface\\AddOns\\Hoard\\media\\profit_arrow.tga";
local ICON_ARROW_LOSS	= "Interface\\AddOns\\Hoard\\media\\loss_arrow.tga";

local ICON_PATTERN_12 = "|T%s:12:12:0:0|t";
local TEX_ADDON_ICON 	= ICON_PATTERN_12:format(ICON_ADDON)
local TEX_ARROW_PROFIT 	= ICON_PATTERN_12:format(ICON_ARROW_PROFIT)
local TEX_ARROW_LOSS 	= ICON_PATTERN_12:format(ICON_ARROW_LOSS)
-- local TEX_EXCLAMATION = [[|TInterface\OptionsFrame\UI-OptionsFrame-NewFeatureIcon:0:0:0:1|t]];

local CONNECTED_REALM, HOME_REALM, PLAYER_FACTION, PLAYER_NAME;

local factionIcons = {
	Alliance = [[|TInterface\BattlefieldFrame\Battleground-Alliance:16:16:0:0:32:32:4:26:4:27|t ]],
	Horde = [[|TInterface\BattlefieldFrame\Battleground-Horde:16:16:0:0:32:32:5:25:5:26|t ]],
}

local function GetPlayerName()
	local n, s = UnitFullName("player");
	return table.concat({n, s}, "-");
end

local function GetConnectedRealmsName()
	local combinedRealmName = "";
	local realms = GetAutoCompleteRealms();
	
	if(realms) then
		combinedRealmName = table.concat(realms, "-");
	else
		combinedRealmName = string.gsub(GetRealmName(), " ", "");
	end
	
	return combinedRealmName;
end

local function roundnum(num)
	return tonumber(string.format("%d", num));
end

local function roundfloat(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

local DISPLAY_PLAYER_GOLD = 1;
local DISPLAY_REALM_GOLD = 2; 

function A:OnEnable()
	CONNECTED_REALM = GetConnectedRealmsName();
	HOME_REALM = string.gsub(GetRealmName(), " ", "");
	PLAYER_FACTION = UnitFactionGroup("player");
	PLAYER_NAME = GetPlayerName();
	
	A:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
	
	A:RegisterEvent("PLAYER_MONEY");
	A:RegisterEvent("CVAR_UPDATE");
	
	A:RegisterEvent("MAIL_SHOW");
	A:RegisterEvent("MAIL_CLOSED");
	A:RegisterEvent("MAIL_INBOX_UPDATE");
	A:RegisterEvent("MAIL_SEND_SUCCESS");
	
	local defaults = {
		global = {
			displayHint = true,
			
			displayMode = DISPLAY_PLAYER_GOLD,
			onlyGold = false,
			shortDisplay = false,
			literalEnabled = false,
			
			showToday = true,
			showYesterday = true,
			showWeek = true,
			onlyHistoryTotals = false,
			
			realms = {
				["*"] = { -- Connected Realms
					["*"] = { -- Faction
						stats = {
							["*"] = {	-- Date
								gained = 0,
								lost = 0,
							},
						},
						archived = {},
						characters = {
							["*"] = {	-- Character Name
								gold = -1,
								inMail = 0,
								class = nil,
							},
						},
					},
					-- ["Neutral"] = {},
				},
			},
		},
	};
	
	A.SessionData = {
		gained = 0,
		lost = 0,
		total = 0,
	};
	
	A.MailMoney = 0;
	A.MailMoneyBuffer = 0;
	
	self.db = AceDB:New("HoardDB", defaults);
	-- A:SetupDatabase();
	
	A:PLAYER_MONEY();
	
	A:CreateBroker();
	A:UpdateBrokerText();
end

function A:OnDisable()
	
end

function A:OnInitialize()
	
end

function A:NEUTRAL_FACTION_SELECT_RESULT()
	local newFaction = UnitFactionGroup("player");
	
	local characterData = A:GetCharacterData();
	local newCharacterData = A:GetCharacterData(newFaction);
	
	newCharacterData[PLAYER_NAME] = {
		gold = characterData[PLAYER_NAME].gold,
		class = characterData[PLAYER_NAME].class,
		inMail = characterData[PLAYER_NAME].inMail,	-- Should definitely be 0/nil if player was pandaren but copying it anyway
	};
	
	-- Remove character's entry in neutral faction
	characterData[PLAYER_NAME] = nil;
	
	PLAYER_FACTION = newFaction;
	
	-- Money sort of appeared from nowhere when character chose faction so let's record it
	A:AddRecord(newCharacterData[PLAYER_NAME].gold);
end

function A:GetContextMenuData()
	local characterRemovalMenuData = {};
	
	local firstFaction = true;
	local realmData = A:GetConnectedRealmData(false);
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
			
			name_token = string.format(A:GetClassColor(data.class), name_token);
			
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
			text = TEX_ADDON_ICON .. " Hoard Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Display Character Gold",
			func = function() self.db.global.displayMode = DISPLAY_PLAYER_GOLD; A:UpdateBrokerText(); end,
			checked = function() return self.db.global.displayMode == DISPLAY_PLAYER_GOLD; end,
		},
		{
			text = "Display Total Realm Gold",
			func = function() self.db.global.displayMode = DISPLAY_REALM_GOLD; A:UpdateBrokerText(); end,
			checked = function() return self.db.global.displayMode == DISPLAY_REALM_GOLD; end,
		},
		{
			text = "|cffffffffDisplay Values using Letters|r" .. colorBlindModeText,
			func = function() self.db.global.literalEnabled = not self.db.global.literalEnabled; A:UpdateBrokerText(); end,
			checked = function() return self.db.global.literalEnabled or colorBlindModeEnabled; end,
			isNotRadio = true,
			disabled = colorBlindModeEnabled,
		},
		{
			text = "Shortened Display",
			func = function() self.db.global.shortDisplay = not self.db.global.shortDisplay; A:UpdateBrokerText(); end,
			checked = function() return self.db.global.shortDisplay; end,
			isNotRadio = true,
			tooltip = "hai",
		},
		{
			text = "Only Show Gold",
			func = function() self.db.global.onlyGold = not self.db.global.onlyGold; A:UpdateBrokerText(); end,
			checked = function() return self.db.global.onlyGold; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "History Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Show Today",
			func = function() self.db.global.showToday = not self.db.global.showToday; end,
			checked = function() return self.db.global.showToday; end,
			isNotRadio = true,
		},
		{
			text = "Show Yesterday",
			func = function() self.db.global.showYesterday = not self.db.global.showYesterday; end,
			checked = function() return self.db.global.showYesterday; end,
			isNotRadio = true,
		},
		{
			text = "Show Past Week",
			func = function() self.db.global.showWeek = not self.db.global.showWeek; end,
			checked = function() return self.db.global.showWeek; end,
			isNotRadio = true,
		},
		{
			text = "Only Display Totals",
			func = function() self.db.global.onlyHistoryTotals = not self.db.global.onlyHistoryTotals; end,
			checked = function() return self.db.global.onlyHistoryTotals; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Miscellaneous", isTitle = true, notCheckable = true,
		},
		{
			text = "Display Tooltip Hint",
			func = function() self.db.global.displayHint = not self.db.global.displayHint; end,
			checked = function() return self.db.global.displayHint; end,
			isNotRadio = true,
		},
		{
			text = "Remove Character",
			menuList = characterRemovalMenuData,
			hasArrow = true,
			notCheckable = true,
		},
		{
			text = "Reset Session",
			func = function() A.SessionData = { gained = 0, lost = 0, total = 0, };  end,
			notCheckable = true,
		},
	};
	
	return contextMenuData;
end

function A:OpenContextMenu(parentFrame)
	if(not A.ContextMenu) then
		A.ContextMenu = CreateFrame("Frame", ADDON_NAME .. "ContextMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	
	A.ContextMenu:SetPoint("BOTTOM", parentFrame or "UIParent", "BOTTOM", 0, 5);
	EasyMenu(A:GetContextMenuData(), A.ContextMenu, parentFrame or "CURSOR", 0, 0, "MENU", 5);
end

function A:CVAR_UPDATE(event, cvar, new_value)
	if(cvar == "USE_COLORBLIND_MODE") then
		CloseMenus();
		A:UpdateBrokerText();
	end
end

function A:PLAYER_MONEY()
	local playerData = A:GetPlayerData();
	local playerMoney = GetMoney();
	
	if(playerData.gold >= 0) then
		local diff = playerMoney - playerData.gold;
		
		if(diff > 0 and playerData.inMail > 0 and A.MailMoneyBuffer > 0) then
			playerData.inMail = playerData.inMail - A.MailMoneyBuffer;
			diff = diff - A.MailMoneyBuffer;
			A.MailMoneyBuffer = 0;
		elseif(diff < 0 and A.MoneySentToAlt) then
			diff = 0;
			A.MoneySentToAlt = false;
		end
		
		A:AddRecord(diff);
	end
	
	playerData.gold = playerMoney;
	
	A:UpdateBrokerText();
end

function A:FixName(name)
	local name_token, realm_token = strsplit("-", name, 2);
	return string.format("%s-%s", name_token, realm_token or GetRealmName());
end

function A:IsOwnCharacter(name)
	name = A:FixName(name);
	
	local characters = A:GetCharacterData();
	if(characters[name].gold ~= -1) then
		return true, characters[name];
	else
		characters[name] = nil;
		return false, nil;
	end
end

function A:MAIL_SHOW()
	A.MailOpen = true;
	A.MailRescan = true;
	
	if(not A.MailHooked) then
		hooksecurefunc("SetSendMailMoney", function(amount)
			A.MailMoney = amount;
		end);
		
		hooksecurefunc("TakeInboxMoney", function(index)
			local mail = A.MailCache[index];
			if(A:IsOwnCharacter(mail.sender) and mail.money > 0) then
				A.MailMoneyBuffer = mail.money;
			end
		end);

		hooksecurefunc("AutoLootMailItem", function(index)
			local mail = A.MailCache[index];
			if(A:IsOwnCharacter(mail.sender) and mail.money > 0) then
				A.MailMoneyBuffer = mail.money;
			end
		end);
		
		A.MailHooked = true;
	end
end

function A:MAIL_CLOSED()
	A.MailOpen = false;
	A.MailRescan = true;
end

function A:MAIL_INBOX_UPDATE()
	if(not A.MailOpen) then return end
	
	A.MailCache = {};
	
	local inboxNum = GetInboxNumItems();
	if(inboxNum > 0) then
		local mailMoney = 0;
		
		for mail_index = 1, inboxNum do
			local _, _, sender, _, money = GetInboxHeaderInfo(mail_index);
			
			A.MailCache[mail_index] = {
				sender = sender,
				money = money,
			};
			
			-- if(A:IsOwnCharacter(sender) and money > 0) then
			-- 	mailMoney = mailMoney + money;
			-- end
		end
		
		-- local playerData = A:GetPlayerData();
		-- if(A.MailRescan) then
		-- 	playerData.inMail = mailMoney;
		-- 	A.MailRescan = false;
		-- end
		
		A:UpdateBrokerText();
	end
end

function A:MAIL_SEND_SUCCESS()
	local recipient = strtrim(SendMailNameEditBox:GetText());
	recipient = A:FixName(recipient);
	
	local isOwn, characterData = A:IsOwnCharacter(recipient);
	if(isOwn) then
		A.MoneySentToAlt = true;
		characterData.inMail = characterData.inMail + A.MailMoney;
	end
	
	A.MailMoney = 0;
end

function A:GetPlayerGold()
	local playerData = A:GetPlayerData();
	return playerData.gold, playerData.inMail;
end

function A:GetRealmGold()
	local characters = A:GetCharacterData();
	local totalGold = 0;
	for name, data in pairs(characters) do
		if(data.gold > 0 or data.inMail > 0) then
			totalGold = totalGold + data.gold + data.inMail;
		end
	end
	
	return totalGold;
end

function A:AddRecord(money_diff, addToSession)
	if(money_diff == nil or money_diff == 0) then return end
	if(PLAYER_FACTION == "Neutral") then return end
	
	local date = A:GetDate();
	local statsData = A:GetStatsData();
	
	if(money_diff > 0) then
		statsData[date].gained = statsData[date].gained + money_diff;
		A.SessionData.gained = A.SessionData.gained + money_diff;
	elseif(money_diff < 0) then
		statsData[date].lost = statsData[date].lost + math.abs(money_diff);
		A.SessionData.lost = A.SessionData.lost + math.abs(money_diff);
	end
	
	A.SessionData.total = A.SessionData.gained - A.SessionData.lost;
end

function A:GetHistory()
	local today 	= A:GetDate();
	local yesterday = A:GetDate(-1);
	local week_ago 	= A:GetDate(-7);
	
	local statsData = A:GetStatsData();
	local archive = A:GetArchive();
	
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

function A:GetRealmsData()
	return self.db.global.realms;
end
	
function A:GetConnectedRealmData(faction)
	local realmData = A:GetRealmsData()[GetConnectedRealmsName()];
	
	if(faction ~= false) then
		return realmData[faction or PLAYER_FACTION];
	end
	
	return realmData;
end

function A:GetCharacterData(faction)
	return A:GetConnectedRealmData(faction or PLAYER_FACTION).characters;
end

function A:GetPlayerData()
	local player = A:GetCharacterData()[PLAYER_NAME];
	
	if(player.class == nil) then
		player.class = select(2, UnitClass("player"));
	end
	
	return player;
end

function A:GetStatsData()
	return A:GetConnectedRealmData().stats;
end

function A:GetArchive()
	return A:GetConnectedRealmData().archived;
end

function A:GetDate(days_diff)
	if(not days_diff) then days_diff = 0 end
	return tonumber(date("%Y%m%d", time() + days_diff * 86400));
end

function A:ParseDate(date)
	local year, month, day = strmatch(tostring(date), "(%d%d%d%d)(%d%d)(%d%d)");
	return tonumber(year), tonumber(month), tonumber(day);
end

local CLASS_COLOR = '|cff%02x%02x%02x';
function A:GetClassColor(class)
	local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class or 'PRIEST'];
	return CLASS_COLOR:format(color.r * 255, color.g * 255, color.b * 255) .. "%s|r";
end

function A:SetTooltip(tooltip, name, data)
	local name_token, realm_token = strsplit('-', name)
	if(realm_token == HOME_REALM) then
		name = name_token;
	else
		name = string.format("%s-%s", name_token, strsub(realm_token, 0, 3));
	end
	
	local faction_icon = "";
	-- if(data.faction == "Alliance") then
	-- 	faction_icon = factionIcons.Alliance;
	-- elseif(data.faction == "Horde") then
	-- 	faction_icon = factionIcons.Horde;
	-- end
	
	local color = A:GetClassColor(data.class);
	
	local mail_icon = "";
	if(data.inMail > 0) then
		mail_icon = " |cff0eb8dcM|r";
	end
	
	tooltip:AddDoubleLine(
		string.format("%s%s%s", faction_icon, string.format(color, name), mail_icon),
		A:GetCorrectCoinString(data.gold + data.inMail), nil, nil, nil, 1, 1, 1);
end

function A:GetTotalColor(total)
	if(total == nil) then return 1, 0, 1 end
	
	if(total > 0) then
		return 0.647, 0.918, 0.063;
	elseif(total < 0) then
		return 0.953, 0.212, 0.212;
	end
	
	return 1, 1, 1;
end

function A:CreateBroker()
	A.Broker = LDB:NewDataObject(ADDON_NAME, {
		type = "data source",
		label = "Hoard",
		text = "",
		icon = ICON_ADDON,
		OnClick = function(frame, button)
			if(button == "LeftButton") then
				
			elseif(button == "RightButton") then
				GameTooltip:Hide();
				A:OpenContextMenu(frame);
			end
		end,
		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then return end
			tooltip:AddLine(TEX_ADDON_ICON .. " Hoard")
			
			tooltip:AddDoubleLine("Session", A:GetCorrectCoinString(A.SessionData.total), nil, nil, nil, A:GetTotalColor(A.SessionData.total));
			tooltip:AddDoubleLine(TEX_ARROW_PROFIT .. " Profit", A:GetCorrectCoinString(A.SessionData.gained), 1, 1, 1, 1, 1, 1);
			tooltip:AddDoubleLine(TEX_ARROW_LOSS .. " Loss", A:GetCorrectCoinString(A.SessionData.lost), 1, 1, 1, 1, 1, 1);
			tooltip:AddLine(" ")
			
			if(PLAYER_FACTION ~= "Neutral") then
				local history = A:GetHistory();
				
				if(self.db.global.showToday) then
					tooltip:AddDoubleLine("Today", A:GetCorrectCoinString(history.today.total), nil, nil, nil, A:GetTotalColor(history.today.total));
					if(not self.db.global.onlyHistoryTotals) then
						tooltip:AddDoubleLine(TEX_ARROW_PROFIT .. " Profit", A:GetCorrectCoinString(history.today.gained), 1, 1, 1, 1, 1, 1);
						tooltip:AddDoubleLine(TEX_ARROW_LOSS .. " Loss", A:GetCorrectCoinString(history.today.lost), 1, 1, 1, 1, 1, 1);
						tooltip:AddLine(" ");
					end
				end
				
				if(self.db.global.showYesterday) then
					tooltip:AddDoubleLine("Yesterday", A:GetCorrectCoinString(history.yesterday.total), nil, nil, nil, A:GetTotalColor(history.yesterday.total));
					if(not self.db.global.onlyHistoryTotals) then
						tooltip:AddDoubleLine(TEX_ARROW_PROFIT .. " Profit", A:GetCorrectCoinString(history.yesterday.gained), 1, 1, 1, 1, 1, 1);
						tooltip:AddDoubleLine(TEX_ARROW_LOSS .. " Loss", A:GetCorrectCoinString(history.yesterday.lost), 1, 1, 1, 1, 1, 1);
						tooltip:AddLine(" ");
					end
				end
				
				if(self.db.global.showWeek) then
					tooltip:AddDoubleLine("Past Week", A:GetCorrectCoinString(history.week_total.total), nil, nil, nil, A:GetTotalColor(history.week_total.total));
					if(not self.db.global.onlyHistoryTotals) then
						tooltip:AddDoubleLine(TEX_ARROW_PROFIT .. " Profit", A:GetCorrectCoinString(history.week_total.gained), 1, 1, 1, 1, 1, 1);
						tooltip:AddDoubleLine(TEX_ARROW_LOSS .. " Loss", A:GetCorrectCoinString(history.week_total.lost), 1, 1, 1, 1, 1, 1);
						tooltip:AddLine(" ");
					end
				end
				
				if(self.db.global.onlyHistoryTotals) then tooltip:AddLine(" "); end
			else
				tooltip:AddLine("Choose a faction to view gold history");
				tooltip:AddLine(" ");
			end
			
			do
				local characters = A:GetCharacterData();
				local totalGold = 0;
				
				local list_characters = {};
				for name, data in pairs(characters) do
					table.insert(list_characters, {name = name, data = data});
					totalGold = totalGold + data.gold + data.inMail;
				end
				
				table.sort(list_characters, function(a, b)
					if(a == nil and b == nil) then return false end
					if(a == nil) then return true end
					if(b == nil) then return false end
					
					return (a.data.gold + a.data.inMail) > (b.data.gold + b.data.inMail);
				end);
				
				for k, data in ipairs(list_characters) do
					A:SetTooltip(tooltip, data.name, data.data);
				end
				
				if(#list_characters > 1) then
					tooltip:AddLine(" ")
					tooltip:AddDoubleLine("Total", A:GetCorrectCoinString(totalGold), nil, nil, nil, 1, 1, 1);
				end
			end
			
			if(self.db.global.displayHint) then
				tooltip:AddLine(" ")
				-- tooltip:AddDoubleLine("Hold Shift", "|cffffffffDisplay all characters|r");
				tooltip:AddDoubleLine("Right-Click", "|cffffffffOpen options menu|r");
			end
			
			A.TooltipOpen = true;
		end,
		OnLeave = function(frame)
			A.TooltipOpen = false;
		end,
	})
end

-- /run ChatFrame1:AddMessage(Hoard:GetCoinText(GetMoney()))

function A:NormalizeCoinValue(coin)
	if(coin == nil) then return 0 end
	coin = tonumber(coin) or 0;
	return math.abs(coin), coin >= 0 and 1 or -1;
end

function A:GetCorrectCoinString(coin)
	coin, sign = A:NormalizeCoinValue(coin)
	
	local prefix = "";
	if(sign == -1) then prefix = "-" end
	
	local useLiteralMode = self.db.global.literalEnabled or GetCVar("colorblindMode") == "1";
	
	if(useLiteralMode) then
		return prefix .. A:GetLiteralCoinString(coin);
	end
	
	return prefix .. strtrim(GetCoinTextureString(coin, 12)) .. "  ";
end

function A:GetLiteralCoinString(coin)
	coin, sign = A:NormalizeCoinValue(coin)
	
	local copper = coin % 100;
	local silver = math.floor((coin % 10000) / 100);
	local gold 	 = math.floor(coin / 10000);
	
	local GOLD 	 = "%d|cfff0c80bg|r ";
	local SILVER = "%d|cffc7c7c7s|r ";
	local COPPER = "%d|cffe67f35c|r";
	
	local result = "";
	
	if(gold > 0) then
		result = string.format("%s%s", result, GOLD:format(gold));
	end
	
	if(silver > 0) then
		result = string.format("%s%s", result, SILVER:format(silver));
	end
	
	if(copper > 0 or (gold == 0 and silver == 0)) then
		result = string.format("%s%s", result, COPPER:format(copper));
	end
	
	return strtrim(result);
end

-- /run ChatFrame1:AddMessage(Hoard:GetShortCoinString(100000))
function A:GetShortCoinString(coin, literal)
	if(literal == nil) then literal = false end
	
	coin, sign = A:NormalizeCoinValue(coin)
	
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

function A:UpdateBrokerText()
	if(not A.Broker) then return end
	
	local displayGold = 0;
	
	if(self.db.global.displayMode == DISPLAY_PLAYER_GOLD) then
		displayGold = A:GetPlayerGold();
	elseif(self.db.global.displayMode == DISPLAY_REALM_GOLD) then
		displayGold = A:GetRealmGold();
	end
	
	if(self.db.global.onlyGold and displayGold >= 10000) then
		displayGold = displayGold - (displayGold % 10000);
	end
	
	local useLiteralMode = self.db.global.literalEnabled or GetCVar("colorblindMode") == "1";
	
	if(self.db.global.shortDisplay) then
		A.Broker.text = A:GetShortCoinString(displayGold, useLiteralMode);
	elseif(useLiteralMode) then
		A.Broker.text = A:GetLiteralCoinString(displayGold);
	else
		A.Broker.text = GetCoinTextureString(displayGold, 12)
	end
end
