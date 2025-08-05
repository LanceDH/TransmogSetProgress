local _addonName, _addon = ...;

local TSP = LibStub("AceAddon-3.0"):NewAddon("TransmogSetProgress");

local _L = {};
_L["SETTING_HANDLE_EMPTY_LABEL"] = "Completed Variants";
_L["SETTING_HANDLE_EMPTY_TOOLTIP"] = "Alter what should be done with set variants that have been completed.";
_L["SETTING_HANDLE_EMPTY_KEEP_LABEL"] = "Unchanged";
_L["SETTING_HANDLE_EMPTY_KEEP_TOOLTIP"] = "Keep completed variants as is.";
_L["SETTING_HANDLE_EMPTY_LEFT_LABEL"] = "Align Left";
_L["SETTING_HANDLE_EMPTY_LEFT_TOOLTIP"] = "Hide completed variants and align the remaining left.";
_L["SETTING_HANDLE_EMPTY_SPREAD_LABEL"] = "Stretched";
_L["SETTING_HANDLE_EMPTY_SPREAD_TOOLTIP"] = "Hide completed variants and stretch the remaining.";
_L["SETTING_HANDLE_EMPTY_SOLID_LABEL"] = "Solid";
_L["SETTING_HANDLE_EMPTY_SOLID_TOOLTIP"] = "Replace completed variants with a solid block.";
_L["SETTING_HANDLE_EMPTY_HIDE_LABEL"] = "Hide";
_L["SETTING_HANDLE_EMPTY_HIDE_TOOLTIP"] = "Hide completed variants and keep others in place.";
_L["SETTING_COLOR_LABEL"] = "Variant Colors";
_L["SETTING_COLOR_TOOLTIP"] = "Define the colors for the individual variant bars.";
_L["SETTING_COLOR_UNIFORM_LABEL"] = "Green";
_L["SETTING_COLOR_UNIFORM_TOOLTIP"] = "Color all variants a uniform green.";
_L["SETTING_COLOR_ADDON_LABEL"] = "Default";
_L["SETTING_COLOR_ADDON_TOOLTIP"] = "Each variant has a muted version of the default item quality colors.";
_L["SETTING_COLOR_ITEM_QUALITY_LABEL"] = "Item Quality";
_L["SETTING_COLOR_ITEM_QUALITY_TOOLTIP"] = "Uses the item quality colors as defined in your accessibility settings.";
_L["SETTING_BAR_HIGHLIGHT_LABEL"] = "Bar Over Highlight";
_L["SETTING_BAR_HIGHLIGHT_Tooltip"] = "Show the progress bar should over the button's highlight texture.";

local TSP_COLORS = {
			[0]	= { ["bright"] = CreateColor(0.00, 0.65, 0.00), ["dim"] = CreateColor(0.00, 0.35, 0.00)};
			[1] = { ["bright"] = CreateColor(0.00, 0.65, 0.00), ["dim"] = CreateColor(0.00, 0.35, 0.00)};
			[2] = { ["bright"] = CreateColor(0.00, 0.45, 0.85), ["dim"] = CreateColor(0.00, 0.25, 0.40)};
			[3] = { ["bright"] = CreateColor(0.65, 0.30, 0.80), ["dim"] = CreateColor(0.30, 0.15, 0.40)};
			[4] = { ["bright"] = CreateColor(0.75, 0.40, 0.00), ["dim"] = CreateColor(0.40, 0.20, 0.00)};
			[5] = { ["bright"] = CreateColor(0.80, 0.70, 0.45), ["dim"] = CreateColor(0.40, 0.35, 0.25)};
			[6] = { ["bright"] = CreateColor(0.00, 0.70, 0.90), ["dim"] = CreateColor(0.00, 0.35, 0.45)};
		};

local n10 = string.format("%s (%s)", RAID_DIFFICULTY1, PLAYER_DIFFICULTY1);
local n25 = string.format("%s (%s)", RAID_DIFFICULTY2, PLAYER_DIFFICULTY1);
local h10 = string.format("%s (%s)", RAID_DIFFICULTY1, PLAYER_DIFFICULTY2);
local h25 = string.format("%s (%s)", RAID_DIFFICULTY2, PLAYER_DIFFICULTY2);

local TSP_DESC_TO_COLOR_INDEX = {
		[PLAYER_DIFFICULTY3] = 1;
		[PLAYER_DIFFICULTY1] = 2;
		[PLAYER_DIFFICULTY2] = 3;
		[PLAYER_DIFFICULTY6] = 4;

		[n10] = 1;
		[n25] = 2;
		[h10] = 3;
		[h25] = 4;
	};

local ENUM_EMPTY_OPTION = EnumUtil.MakeEnum(
		"keep",
		"left",
		"spread",
		"solid",
		"hide"
	);

local ENUM_COLOR_OPTION = EnumUtil.MakeEnum(
		"addon",
		"uniform",
		"itemQuality"
	);

local TSP_FAKE_SET_VARIANTS = {
	{ setID = -1, expansionID = 4 };
	{ setID = -2, expansionID = 3 };
	{ setID = -3, expansionID = 2 };
	{ setID = -4, expansionID = 1 };
};

local TSP_FAKE_SET_SOURCE_COUNTS = {
	[-1] = {
		numCollected = 4;
		numTotal = 9;
	};
	[-2] = {
		numCollected = 9;
		numTotal = 9;
	};
	[-3] = {
		numCollected = 1;
		numTotal = 9;
	};
	[-4] = {
		numCollected = 5;
		numTotal = 9;
	};
};

local TSP_DEFAULTS = {
	global = {
		handleEmpty = ENUM_EMPTY_OPTION.solid;
		colorType = ENUM_COLOR_OPTION.addon;
		barOverHighlight = false;
	}
}

local SET_BAR_SPACING = 5;
local SET_BAR_SPACING_TINY = 2;
local MIN_SETS_FOR_TINY_BAR_SPACING = 10;
local BAR_BLOCK_SPACING = 2;
local BAR_BLOCK_SPACING_TINY = 1;

local NUM_COLORS = 6;
local GREEN_COLOR_INDEX = 1;
local BLIZZARD_GREEN_COLOR_INDEX = 2;

TSP.SetsDataProvider = nil;

TSP_CORE_MIXIN = {};

function TSP:WrapperGetSetSourceCounts(setID)
	if (setID < 0) then
		local fakeSet = TSP_FAKE_SET_SOURCE_COUNTS[setID] or TSP_FAKE_SET_SOURCE_COUNTS[-1];
		return fakeSet.numCollected, fakeSet.numTotal;
	elseif(TSP.SetsDataProvider) then
		return TSP.SetsDataProvider:GetSetSourceCounts(setID);
	end

	return 0, 0;
end

-- Adds variants to a provided table so we can mess with order and remove items without changing the original table
function TSP:WrapperGetVariantSets(setID, table)
	wipe(table);

	if (setID < 0) then
		tAppendAll(table, TSP_FAKE_SET_VARIANTS);
	elseif(TSP.SetsDataProvider) then
		tAppendAll(table, TSP.SetsDataProvider:GetVariantSets(setID));
	end
end

function TSP:OnSetButtonInitialized(button, data)
	if (not data.setID) then return; end

	if (not button.TSPBar) then
		button.TSPBar = CreateFrame("FRAME", nil, button, "TSP_MainBarTemplate");
	end

	local frameLevel = button:GetFrameLevel();
	if (TSP.settings.barOverHighlight) then
		frameLevel = frameLevel + 1;
	end
	button.TSPBar:SetFrameLevel(frameLevel);

	button.ProgressBar:SetAlpha(0);
	button.TSPBar:SetupSetByID(data.setID, frameLevel);
end

function TSP:GetVariantColors(variantData, index)
	if (TSP.settings.colorType == ENUM_COLOR_OPTION.uniform) then
		local variantColorData = TSP_COLORS[GREEN_COLOR_INDEX];
		local unlockedR, unlockedG, unlockedB = variantColorData.bright:GetRGB();
		local lockedR, lockedG, lockedB = variantColorData.dim:GetRGB();
		return unlockedR, unlockedG, unlockedB, lockedR, lockedG, lockedB;
	end

	local desc = variantData.description;
	local colorIndex = TSP_DESC_TO_COLOR_INDEX[desc] or index;

	if (TSP.settings.colorType == ENUM_COLOR_OPTION.itemQuality) then
		colorIndex = ((colorIndex-1) % NUM_COLORS) + BLIZZARD_GREEN_COLOR_INDEX;

		local color = ITEM_QUALITY_COLORS[colorIndex] or ITEM_QUALITY_COLORS[BLIZZARD_GREEN_COLOR_INDEX];
		return color.r, color.g, color.b, color.r * 0.5, color.g * 0.5, color.b * 0.5;
	end

	colorIndex = ((colorIndex-1) % NUM_COLORS) + GREEN_COLOR_INDEX;
	local variantColorData = TSP_COLORS[colorIndex] or TSP_COLORS[GREEN_COLOR_INDEX];

	local unlockedR, unlockedG, unlockedB = variantColorData.bright:GetRGB();
	local lockedR, lockedG, lockedB = variantColorData.dim:GetRGB();
	return unlockedR, unlockedG, unlockedB, lockedR, lockedG, lockedB;
end



TSP_PREVIEW_BUTTON_MIXIN = {}

function TSP_PREVIEW_BUTTON_MIXIN:OnLoad()
	self.IconFrame.Icon:SetTexture(5740527);

	local fakeData = TSP_FAKE_SET_VARIANTS[1];
	TSP:OnSetButtonInitialized(self, fakeData);
end

function TSP_PREVIEW_BUTTON_MIXIN:OnClick()
	self.SelectedTexture:SetShown(not self.SelectedTexture:IsShown());
end

TSP_SETTINGS_MIXIN = CreateFromMixins(SettingsControlMixin);

function TSP_SETTINGS_MIXIN:OnLoad()
	SettingsControlMixin.OnLoad(self);

	self.Tooltip:EnableMouse(false);
end



TPS_VARIANT_BAR_MIXIN = {};

function TPS_VARIANT_BAR_MIXIN:OnLoad()
	self.barBlocks = {};
end

function TPS_VARIANT_BAR_MIXIN:SetupVariant(variantData, index, spacing, frameLevel)
	local numCollected, numTotal = TSP:WrapperGetSetSourceCounts(variantData.setID);

	if (numCollected == numTotal) then
		if (TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.solid) then
			numCollected = 1;
			numTotal = 1;
		elseif (TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.hide) then
			for _, block in ipairs(self.barBlocks) do
				TSP.barBlockPool:Release(block);
			end
			wipe(self.barBlocks);
			return;
		end
	end

	for i = #self.barBlocks, numTotal + 1, -1 do
		local block = self.barBlocks[i];
		TSP.barBlockPool:Release(block);
		tremove(self.barBlocks, i);
	end

	local unlockedR, unlockedG, unlockedB, lockedR, lockedG, lockedB = TSP:GetVariantColors(variantData, index);

	local totalSpacing = spacing * (numTotal - 1);
	local availableSpace = self:GetWidth() - totalSpacing;
	local sizePerBlock = availableSpace / numTotal;
	

	for i = 1, numTotal, 1 do
		local frame = self.barBlocks[i];
		if (not frame) then
			frame = TSP.barBlockPool:Acquire();
			frame:SetFrameLevel(frameLevel);
			
			tinsert(self.barBlocks, frame);
		end

		frame:Show();
		frame:SetWidth(sizePerBlock);

		local isCollected = i <= numCollected;
		frame.Texture:SetColorTexture(
				(isCollected and unlockedR or lockedR),
				(isCollected and unlockedG or lockedG),
				(isCollected and unlockedB or lockedB)
			);
		frame:SetParent(self);
		frame:ClearAllPoints();
		if (i == 1) then
			frame:SetPoint("LEFT", self);
		else
			frame:SetPoint("LEFT", self.barBlocks[i-1], "RIGHT", spacing, 0);
		end

		if (not TSP.settings.barOverHighlight) then
			frame:SetFrameLevel(frameLevel);
		end
	end
end



TPS_MAINBAR_MIXIN = {};

function TPS_MAINBAR_MIXIN:OnLoad()
	self.variants = {};
	self.setFrames = {};
end

function TPS_MAINBAR_MIXIN:SetupSetByID(setID, frameLevel)
	TSP:WrapperGetVariantSets(setID, self.variants);

	if (#self.variants == 0) then
		local baseSet = TSP.SetsDataProvider:GetBaseSetByID(setID);
		tinsert(self.variants, baseSet);
	end

	-- In case of ENUM_EMPTY_OPTION.left we might want to act like there are more bars than we'll actually show
	local numBarsToShow = #self.variants;

	if (numBarsToShow == 0) then
		for _, frame in ipairs(self.setFrames) do
			TSP.variantBarPool:Release(frame);
		end
		wipe(self.setFrames);

		self:Hide();
		return;
	end

	if (TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.left or TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.spread) then
		for i = numBarsToShow, 1, -1 do
			local variantData = self.variants[i];
			local numCollected, numTotal = TSP:WrapperGetSetSourceCounts(variantData.setID);
			if (numCollected == numTotal) then
				tremove(self.variants, i);
			end
		end
		
		if (TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.spread) then
			numBarsToShow = #self.variants;
		end
	end

	for i = #self.setFrames, #self.variants + 1, -1 do
		local frame = self.setFrames[i];
		TSP.variantBarPool:Release(frame);
		tremove(self.setFrames, i);
	end

	if (#self.variants == 0) then
		self:Hide();
		return;
	end

	self:Show();

	local barSpacing = numBarsToShow >= MIN_SETS_FOR_TINY_BAR_SPACING and SET_BAR_SPACING_TINY or SET_BAR_SPACING;
	local totalSpacing = barSpacing * (numBarsToShow - 1);
	local availableSpace = self:GetWidth() - totalSpacing;
	local sizePerSetFrame = availableSpace / numBarsToShow;

	local spacing = numBarsToShow > 3 and BAR_BLOCK_SPACING_TINY or BAR_BLOCK_SPACING;

	for i = 1, #self.variants, 1 do
		local frame = self.setFrames[i];
		if (not frame) then
			frame = TSP.variantBarPool:Acquire();
			tinsert(self.setFrames, frame);
		end

		frame:Show();
		frame:SetWidth(sizePerSetFrame);
		frame:SetParent(self);
		frame:ClearAllPoints();
		if (i == 1) then
			frame:SetPoint("LEFT", self);
		else
			frame:SetPoint("LEFT", self.setFrames[i-1], "RIGHT", barSpacing, 0);
		end

		if (not TSP.settings.barOverHighlight) then
			frame:SetFrameLevel(frameLevel);
		end
		frame:SetupVariant(self.variants[i], i, spacing, frameLevel);
	end
end



function TSP:OnEnable()
	self.db = LibStub("AceDB-3.0"):New("TSPDB", TSP_DEFAULTS, true);
	self.settings = self.db.global;
	

	local oldVersion = self.settings.version;
	if (oldVersion) then
		if (oldVersion < "11.1.01") then
			if (self.settings.AlignLeft) then
				
				self.settings.handleEmpty = ENUM_EMPTY_OPTION.left;
			end

			self.settings.AlignLeft = nil;
			self.settings.HideCompleted = nil;
		end
	end
	
	self.settings.version = C_AddOns.GetAddOnMetadata(_addonName, "version");


	local _, _addonTitle = C_AddOns.GetAddOnInfo(_addonName);
	local category, layout = Settings.RegisterVerticalLayoutCategory(_addonTitle);

	-- Example previes
	local fakeTable = {};
	local previewFakeSettings = Settings.RegisterAddOnSetting(
					category,
					"TSP_PreviewFake",
					"fake",
					fakeTable,
					Settings.VarType.Boolean,
					"",
					Settings.Default.False);
	previewFakeSettings:SetValueChangedCallback(function(setting, value) end);

	local previewInitializer = Settings.CreateControlInitializer("TSP_SettingsPreviewTemplate", previewFakeSettings, nil, nil);
	layout:AddInitializer(previewInitializer);

	local function ReloadPreviewButton()
		TSP_FakePreviewButton:OnLoad();
	end

	-- handleEmpty
	local handleEmptySetting = Settings.RegisterAddOnSetting(
					category,
					"TSP_HANDLE_EMPTY",
					"handleEmpty",
					self.settings,
					Settings.VarType.Number,
					_L["SETTING_HANDLE_EMPTY_LABEL"],
					TSP_DEFAULTS.global.handleEmpty);
	
	handleEmptySetting:SetValueChangedCallback(ReloadPreviewButton);

	local function GetHandleEmptyOptions()
		local container = Settings.CreateControlTextContainer();
		container:Add(ENUM_EMPTY_OPTION.keep, _L["SETTING_HANDLE_EMPTY_KEEP_LABEL"], _L["SETTING_HANDLE_EMPTY_KEEP_TOOLTIP"]);
		container:Add(ENUM_EMPTY_OPTION.solid, _L["SETTING_HANDLE_EMPTY_SOLID_LABEL"], _L["SETTING_HANDLE_EMPTY_SOLID_TOOLTIP"]);
		container:Add(ENUM_EMPTY_OPTION.hide, _L["SETTING_HANDLE_EMPTY_HIDE_LABEL"], _L["SETTING_HANDLE_EMPTY_HIDE_TOOLTIP"]);
		container:Add(ENUM_EMPTY_OPTION.left, _L["SETTING_HANDLE_EMPTY_LEFT_LABEL"], _L["SETTING_HANDLE_EMPTY_LEFT_TOOLTIP"]);
		container:Add(ENUM_EMPTY_OPTION.spread, _L["SETTING_HANDLE_EMPTY_SPREAD_LABEL"], _L["SETTING_HANDLE_EMPTY_SPREAD_TOOLTIP"]);
		return container:GetData();
	end

	Settings.CreateDropdown(category, handleEmptySetting, GetHandleEmptyOptions, _L["SETTING_HANDLE_EMPTY_TOOLTIP"]);

	-- colors
	local colorsSetting = Settings.RegisterAddOnSetting(
					category,
					"TSP_COLOR_TYPE",
					"colorType",
					self.settings,
					Settings.VarType.Number,
					_L["SETTING_COLOR_LABEL"],
					TSP_DEFAULTS.global.colorType);
	
	colorsSetting:SetValueChangedCallback(ReloadPreviewButton);

	local function GetColorsOptions()
		local container = Settings.CreateControlTextContainer();
		container:Add(ENUM_COLOR_OPTION.addon, _L["SETTING_COLOR_ADDON_LABEL"], _L["SETTING_COLOR_ADDON_TOOLTIP"]);
		container:Add(ENUM_COLOR_OPTION.itemQuality, _L["SETTING_COLOR_ITEM_QUALITY_LABEL"], _L["SETTING_COLOR_ITEM_QUALITY_TOOLTIP"]);
		container:Add(ENUM_COLOR_OPTION.uniform, _L["SETTING_COLOR_UNIFORM_LABEL"], _L["SETTING_COLOR_UNIFORM_TOOLTIP"]);
		return container:GetData();
	end

	Settings.CreateDropdown(category, colorsSetting, GetColorsOptions, _L["SETTING_COLOR_TOOLTIP"]);

	-- barLevel
	local barOverHighlightSetting = Settings.RegisterAddOnSetting(
					category,
					"TSP_BAR_OVER_HIGHLIGHT",
					"barOverHighlight",
					self.settings,
					Settings.VarType.Boolean,
					_L["SETTING_BAR_HIGHLIGHT_LABEL"],
					TSP_DEFAULTS.global.barOverHighlight);
	
	barOverHighlightSetting:SetValueChangedCallback(ReloadPreviewButton);

	Settings.CreateCheckbox(category, barOverHighlightSetting, _L["SETTING_BAR_HIGHLIGHT_Tooltip"]);

	Settings.RegisterAddOnCategory(category);

	-- Update in case accessibility colors were changed
	EventRegistry:RegisterCallback(
		"Settings.CategoryChanged",
		function(source, newCategory)
				if (newCategory == category) then
					ReloadPreviewButton();
				end
			end,
		self);
end

local function BarBlockResetFunc(pool, block, new)
	if (new) then return; end
	block:Hide();
end

local function VariantBarResetFunc(pool, bar, new)
	if (new) then return; end
	bar:Hide();
end

function TSP_CORE_MIXIN:OnLoad()
	self.externalsToLoad = {};

	self:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
	self:RegisterEvent("ADDON_LOADED");
	
	TSP.variantBarPool = CreateSecureFramePool("Frame", self, "TSP_VariantBarTemplate", VariantBarResetFunc);
	TSP.barBlockPool = CreateSecureFramePool("Frame", self, "TSP_BarBlockTemplate", BarBlockResetFunc);
end

function TSP_CORE_MIXIN:LoadExternal(addonName)
	local external = self.externalsToLoad[addonName];
	if (not external) then return; end

	self.externalsToLoad[addonName] = nil;
	external:OnLoad(TSP);
end

function TSP_CORE_MIXIN:ProvideExternal(external)
	if (not external or not external.GetAddonName) then return; end

	local name = external:GetAddonName();
	if (not name or name == "") then return; end

	self.externalsToLoad[name] = external;

	if (C_AddOns.IsAddOnLoaded(name)) then
		self:LoadExternal(name);
	end
end

function TSP_CORE_MIXIN:ADDON_LOADED(loaded)
	if (loaded == "Blizzard_Collections") then
		local scrollbox = WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBox;
		scrollbox.view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame, function(source, button, data) TSP:OnSetButtonInitialized(button, data); end, self);

		TSP.SetsDataProvider = CreateFromMixins(WardrobeSetsDataProviderMixin);

		self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
	end

	for name in pairs(self.externalsToLoad) do
		if (name == loaded) then
			self:LoadExternal(name);
			break;
		end
	end
end

function TSP_CORE_MIXIN:TRANSMOG_COLLECTION_UPDATED()
	if (TSP.SetsDataProvider) then
		TSP.SetsDataProvider:ClearSets();
	end
end