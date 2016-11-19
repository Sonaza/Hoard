------------------------------------------------------------
-- Hoard by Sonaza

local ADDON_NAME, SHARED = ...;
local _;

local _G = getfenv(0);

local LibStub = LibStub;
local Addon = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0");

_G[ADDON_NAME] = Addon;
SHARED[1] = Addon;

local LibDataBroker = LibStub("LibDataBroker-1.1");
local LibQTip = LibStub("LibQTip-1.0");
local AceDB = LibStub("AceDB-3.0");

local DATA = {};
SHARED[2] = DATA;

DATA.ICON_ADDON         = "Interface\\Icons\\INV_Misc_Coin_17";

DATA.ICON_PATTERN_10    = "|T%s:10:10:0:0|t";
DATA.ICON_PATTERN_12    = "|T%s:12:12:0:0|t";
DATA.ICON_PATTERN_14    = "|T%s:14:14:0:0|t";
DATA.ICON_PATTERN_16    = "|T%s:16:16:0:0|t";
DATA.TEX_ADDON_ICON     = DATA.ICON_PATTERN_12:format(DATA.ICON_ADDON);
-- DATA.TEX_EXCLAMATION    = [[|TInterface\OptionsFrame\UI-OptionsFrame-NewFeatureIcon:0:0:0:1|t]];

-- Shared enums
local ENUM = {}
SHARED[3] = ENUM;

ENUM.DISPLAY_PLAYER_GOLD  = 1;
ENUM.DISPLAY_REALM_GOLD   = 2;

ENUM.FACTION_ICONS = {
	Alliance  = [[|TInterface\BattlefieldFrame\Battleground-Alliance:16:16:0:0:32:32:4:26:4:27|t ]],
	Horde     = [[|TInterface\BattlefieldFrame\Battleground-Horde:16:16:0:0:32:32:5:25:5:26|t ]],
}

function Addon:GetPlayerName()
	local n, s = UnitFullName("player");
	return table.concat({n, s}, "-");
end

function Addon:GetHomeRealm()
	local name = string.gsub(GetRealmName(), " ", "");
	return name;
end

function Addon:GetConnectedRealms()
	local realms = GetAutoCompleteRealms();
	
	if(realms) then
		return realms;
	else
		return { Addon:GetHomeRealm() };
	end
end

function Addon:GetConnectedRealmsName()
	return table.concat(Addon:GetConnectedRealms(), "-");
end

function Addon:GetOtherFactionName()
	local faction = UnitFactionGroup("player");
	if(faction == "Neutral") then return nil end
	if(faction == "Alliance") then
		return "Horde";
	else
		return "Alliance";
	end
end

function Addon:GetFactionColor(faction)
	if(faction == "Alliance") then return "3594ff"; end
	if(faction == "Horde") then return "ef2626"; end
	return "68b82e";
end

local CONNECTED_REALM, HOME_REALM, PLAYER_FACTION, PLAYER_NAME;
function Addon:GetPlayerInformation()
	if(not CONNECTED_REALM or not HOME_REALM or not PLAYER_FACTION or not PLAYER_NAME) then
		CONNECTED_REALM  = Addon:GetConnectedRealmsName();
		HOME_REALM       = Addon:GetHomeRealm();
		PLAYER_FACTION   = UnitFactionGroup("player");
		PLAYER_NAME      = Addon:GetPlayerName();
	end
	
	return CONNECTED_REALM, HOME_REALM, PLAYER_FACTION, PLAYER_NAME;
end

function Addon:OnEnable()
	Addon:RegisterEvent("CVAR_UPDATE");
	
	local defaults = {
		global = {
			displayHint         = true,
			
			-- Gold settings
			displayMode         = ENUM.DISPLAY_PLAYER_GOLD,
			onlyGold            = false,
			shortDisplay        = false,
			literalEnabled      = false,
			goldLeftSide        = false,
			bothFactionsTooltip = false,
			
			showToday           = true,
			showYesterday       = true,
			showWeek            = true,
			onlyHistoryTotals   = false,
			
			-- Currency settings
			compactCurrencies           = false,
			showCurrencyTip             = true,
			showCharacterCurrencies     = true,
			hideUnused                  = true,
			showTextIfEmpty				= true,
			currencyLeftSide            = false,
			
			currencies = {
				global = {
					watched = {
						[1]		= false,
						[2]		= false,
						[3]		= false,
						[4]		= false,
					},
				},
				characters = {
					["*"] = {
						showPersonal = false,
						watched = nil,
					},
				}
			},
			
			realmAtlas = {
				["*"] = {},
			},
			
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
								currencies = {},
							},
						},
					},
					-- ["Neutral"] = {},
				},
			},
		},
		
		char = {
			useGlobalSettings = false,
			currencies = {},
		},
	};
	
	self.db = AceDB:New("HoardDB", defaults);
	
	Addon:InitializeModules();
end

local MESSAGE_PATTERN = "|cffffbb4fHoard|r %s";
function Addon:AddMessage(pattern, ...)
	DEFAULT_CHAT_FRAME:AddMessage(MESSAGE_PATTERN:format(string.format(pattern, ...)), 1, 1, 1);
end

-------------------------------------------------------------------------

Addon.Modules = {};

function Addon:RegisterModule(name, data)
	if(Addon.Modules[name]) then return false end
	
	Addon.Modules[name] = data;
	Addon.Modules[name].Update = function(self)
		self.dataobject.text = self:GetText();
	end
	
	return true;
end

function Addon:InitializeModules()
	for name, module in pairs(Addon.Modules) do
		module.dataobject = LibDataBroker:NewDataObject(module.name, module.settings);
		module:Initialize();
	end
	
	Addon:UpdateModules();
end

function Addon:UpdateModules()
	for name, module in pairs(Addon.Modules) do
		module:Update();
	end
end

-------------------------------------------------------------------------

function Addon:GetAnchors(frame)
	local B, T = "BOTTOM", "TOP";
	local x, y = frame:GetCenter();
	
	if(y < _G.GetScreenHeight() / 2) then
		return B, T;
	else
		return T, B;
	end
end

function Addon:GetHorizontalAnchors(frame)
	local R, L = "RIGHT", "LEFT";
	local x, y = frame:GetCenter();
	
	if(x < _G.GetScreenWidth() / 2) then
		return L, R;
	else
		return R, L;
	end
end

function Addon:OpenContextMenu(frame, menudata)
	if(not menudata) then return end
	
	if(not Addon.ContextMenu) then
		Addon.ContextMenu = CreateFrame("Frame", ADDON_NAME .. "ContextMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	
	local point, relative = Addon:GetAnchors(frame);
	
	Addon.ContextMenu:ClearAllPoints();
	Addon.ContextMenu:SetPoint(point, frame, relative, 0, 0);
	EasyMenu(menudata, Addon.ContextMenu, frame or "CURSOR", 0, 0, "MENU", 5);
	
	DropDownList1:ClearAllPoints();
	DropDownList1:SetPoint(point, frame, relative, 0, 0);
	DropDownList1:SetClampedToScreen(true);
end

-------------------------------------------------------------------------

function Addon:CVAR_UPDATE(event, cvar, new_value)
	if(cvar == "USE_COLORBLIND_MODE") then
		CloseMenus();
		Addon:UpdateModules();
	end
end

-------------------------------------------------------------------------

local CLASS_COLOR = '|cff%02x%02x%02x';
function Addon:GetClassColor(class)
	local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class or 'PRIEST'];
	return CLASS_COLOR:format(color.r * 255, color.g * 255, color.b * 255) .. "%s|r";
end

--------------------------------------

function Addon:GetRealmsData()
	return self.db.global.realms;
end

local REALM_IDENTIFIER;
function Addon:GetRealmIdentifier()
	if(REALM_IDENTIFIER) then return REALM_IDENTIFIER end
	
	for identifier, realms in pairs(self.db.global.realmAtlas) do
		for _, realm in ipairs(realms) do
			if(realm == HOME_REALM) then
				REALM_IDENTIFIER = identifier;
				return REALM_IDENTIFIER;
			end
		end
	end
	
	tinsert(self.db.global.realmAtlas, Addon:GetConnectedRealms());
	return Addon:GetRealmIdentifier();
end

function Addon:GetConnectedRealmData(faction)
	local realmData = Addon:GetRealmsData()[Addon:GetConnectedRealmsName()];
	
	if(faction ~= false) then
		return realmData[faction or PLAYER_FACTION];
	end
	
	return realmData;
end

function Addon:GetCharacterData(faction)
	return Addon:GetConnectedRealmData(faction or PLAYER_FACTION).characters;
end

function Addon:GetPlayerData()
	local player = Addon:GetCharacterData()[PLAYER_NAME];
	
	if(player.class == nil) then
		player.class = select(2, UnitClass("player"));
	end
	
	return player;
end

function Addon:GetStatsData(realm)
	return Addon:GetConnectedRealmData().stats;
end

function Addon:GetArchive()
	return Addon:GetConnectedRealmData().archived;
end

function Addon:GetCharacterRemovalMenu()
	local menudata = {};
	
	local firstFaction = true;
	local realmData = Addon:GetConnectedRealmData(false);
	for faction, factionData in pairs(realmData) do
		if(not firstFaction) then
			tinsert(menudata, {
				text = " ", isTitle = true, notCheckable = true,
			});
		end
		
		tinsert(menudata, {
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
			
			tinsert(menudata, {
				text = string.format("%s|r%s", name_token, realm_token),
				func = function() factionData.characters[name] = nil; CloseMenus(); end,
				notCheckable = true,
			});
		end
	end
	
	return menudata;
end

--------------------------------------

function Addon:GetDate(days_diff)
	if(not days_diff) then days_diff = 0 end
	return tonumber(date("%Y%m%d", time() + days_diff * 86400));
end

function Addon:ParseDate(date)
	local year, month, day = strmatch(tostring(date), "(%d%d%d%d)(%d%d)(%d%d)");
	return tonumber(year), tonumber(month), tonumber(day);
end
