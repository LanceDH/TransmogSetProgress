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

local TSP_COLORS = {
			[0]	= { ["bright"] = CreateColor(0.00, 0.65, 0.00), ["dim"] = CreateColor(0.00, 0.35, 0.00)};
			[1] = { ["bright"] = CreateColor(0.00, 0.65, 0.00), ["dim"] = CreateColor(0.00, 0.35, 0.00)};
			[2] = { ["bright"] = CreateColor(0.00, 0.50, 0.90), ["dim"] = CreateColor(0.00, 0.25, 0.40)};
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
	{ setID = -1 };
	{ setID = -2 };
	{ setID = -3 };
	{ setID = -4 };
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
	}
}

local SET_BAR_SPACING = 5;
local BAR_BLOCK_SPACING = 2;
local BAR_BLOCK_SPACING_TINY = 1;

local TSP_SetsDataProvider = nil;



local function WrapperGetSetSourceCounts(setID)
	if (setID < 0) then
		local fakeSet = TSP_FAKE_SET_SOURCE_COUNTS[setID] or TSP_FAKE_SET_SOURCE_COUNTS[-1];
		return fakeSet.numCollected, fakeSet.numTotal;
	elseif(TSP_SetsDataProvider) then
		return TSP_SetsDataProvider:GetSetSourceCounts(setID);
	end

	return 0, 0;
end

local function WrapperGetVariantSets(setID)
	if (setID < 0) then
		return TSP_FAKE_SET_VARIANTS;
	elseif(TSP_SetsDataProvider) then
		return TSP_SetsDataProvider:GetVariantSets(setID);
	end

	return {};
end

local function OnSetButtonInitialized(source, button, data)
	if (not data.setID) then return; end

	if (not button.TSPBar) then
		button.TSPBar = CreateFrame("FRAME", nil, button, "TSP_MainBarTemplate");
	end

	button.ProgressBar:SetAlpha(0);
	button.TSPBar:SetupSetByID(data.setID);
end

local function GetVariantColors(variantData, index)
	if (TSP.settings.colorType == ENUM_COLOR_OPTION.uniform) then
		local variantColorData = TSP_COLORS[1];
		local unlockedR, unlockedG, unlockedB = variantColorData.bright:GetRGB();
		local lockedR, lockedG, lockedB = variantColorData.dim:GetRGB();
		return unlockedR, unlockedG, unlockedB, lockedR, lockedG, lockedB;
	end

	local desc = variantData.description;
	local colorIndex = TSP_DESC_TO_COLOR_INDEX[desc] or index;

	local variantColorData = TSP_COLORS[colorIndex] or TSP_COLORS[1];

	if (TSP.settings.colorType == ENUM_COLOR_OPTION.itemQuality) then
		colorIndex = colorIndex + 1;
		local color = ITEM_QUALITY_COLORS[colorIndex];
		return color.r, color.g, color.b, color.r * 0.5, color.g * 0.5, color.b * 0.5;
	end

	local unlockedR, unlockedG, unlockedB = variantColorData.bright:GetRGB();
	local lockedR, lockedG, lockedB = variantColorData.dim:GetRGB();
	return unlockedR, unlockedG, unlockedB, lockedR, lockedG, lockedB;
end



TSP_PREVIEW_BUTTON_MIXIN = {}

function TSP_PREVIEW_BUTTON_MIXIN:OnLoad()
	self.IconFrame.Icon:SetTexture(5740527);

	local fakeData = { setID = -1 };
	OnSetButtonInitialized(nil, self, fakeData);
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

function TPS_VARIANT_BAR_MIXIN:SetupVariant(variantData, index, spacing)
	for _, block in ipairs(self.barBlocks) do
		TSP_EventFrame.barBlockPool:Release(block);
	end
	wipe(self.barBlocks);

	local numCollected, numTotal = WrapperGetSetSourceCounts(variantData.setID);

	if (numCollected == numTotal) then
		if (TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.solid) then
			numCollected = 1;
			numTotal = 1;
		elseif (TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.hide) then
			return;
		end
	end

	local unlockedR, unlockedG, unlockedB, lockedR, lockedG, lockedB = GetVariantColors(variantData, index);

	local totalSpacing = spacing * (numTotal - 1);
	local availableSpace = self:GetWidth() - totalSpacing;
	local sizePerBlock = availableSpace / numTotal;
	

	for i = 1, numTotal, 1 do
		local frame = TSP_EventFrame.barBlockPool:Acquire();
		tinsert(self.barBlocks, frame);

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
	end
end



TPS_MAINBAR_MIXIN = {};

function TPS_MAINBAR_MIXIN:OnLoad()
	self.variants = {};
	self.setFrames = {};
end

function TPS_MAINBAR_MIXIN:SetupSetByID(setID)
	for _, frame in ipairs(self.setFrames) do
		TSP_EventFrame.variantBarPool:Release(frame);
	end
	wipe(self.setFrames);

	-- We move the entries to our own list so that we don't affect the table in the dataprovider
	wipe(self.variants);
	tAppendAll(self.variants, WrapperGetVariantSets(setID));

	if (#self.variants == 0) then
		local baseSet = TSP_SetsDataProvider:GetBaseSetByID(setID);
		tinsert(self.variants, baseSet);
	end

	local numVariants = #self.variants;
	if (numVariants == 0) then return; end


	if (TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.left or TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.spread) then
		for i = numVariants, 1, -1 do
			local variantData = self.variants[i];
			local numCollected, numTotal = WrapperGetSetSourceCounts(variantData.setID);
			if (numCollected == numTotal) then
				tremove(self.variants, i);
			end
		end
		
		if (TSP.settings.handleEmpty == ENUM_EMPTY_OPTION.spread) then
			numVariants = #self.variants;
		end
	end

	local totalSpacing = SET_BAR_SPACING * (numVariants - 1);
	local availableSpace = self:GetWidth() - totalSpacing;
	local sizePerSetFrame = availableSpace / numVariants;

	local spacing = numVariants > 3 and BAR_BLOCK_SPACING_TINY or BAR_BLOCK_SPACING;

	for i = 1, #self.variants, 1 do
		local frame = TSP_EventFrame.variantBarPool:Acquire();
		frame:Show();
		frame:SetWidth(sizePerSetFrame);
		frame:SetParent(self);
		frame:ClearAllPoints();
		if (i == 1) then
			frame:SetPoint("LEFT", self);
		else
			frame:SetPoint("LEFT", self.setFrames[i-1], "RIGHT", SET_BAR_SPACING, 0);
		end

		frame:SetupVariant(self.variants[i], i, spacing);

		tinsert(self.setFrames, frame);
	end

end



function TSP:OnEnable()
	self.db = LibStub("AceDB-3.0"):New("TSPDB", TSP_DEFAULTS, true);
	self.settings = self.db.global;
	

	if (self.settings.version < "11.1.01") then
		if (self.settings.AlignLeft) then
			
			self.settings.handleEmpty = ENUM_EMPTY_OPTION.left;
		end

		self.settings.AlignLeft = nil;
		self.settings.HideCompleted = nil;
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
					ENUM_EMPTY_OPTION.solid);
	
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
					ENUM_COLOR_OPTION.addon);
	
	colorsSetting:SetValueChangedCallback(ReloadPreviewButton);

	local function GetColorsOptions()
		local container = Settings.CreateControlTextContainer();
		container:Add(ENUM_COLOR_OPTION.addon, _L["SETTING_COLOR_ADDON_LABEL"], _L["SETTING_COLOR_ADDON_TOOLTIP"]);
		container:Add(ENUM_COLOR_OPTION.itemQuality, _L["SETTING_COLOR_ITEM_QUALITY_LABEL"], _L["SETTING_COLOR_ITEM_QUALITY_TOOLTIP"]);
		container:Add(ENUM_COLOR_OPTION.uniform, _L["SETTING_COLOR_UNIFORM_LABEL"], _L["SETTING_COLOR_UNIFORM_TOOLTIP"]);
		return container:GetData();
	end

	Settings.CreateDropdown(category, colorsSetting, GetColorsOptions, _L["SETTING_COLOR_TOOLTIP"]);
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

local TSP_EventFrame = CreateFrame("FRAME", "TSP_EventFrame"); 
TSP_EventFrame:RegisterEvent("ADDON_LOADED");
TSP_EventFrame:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
TSP_EventFrame.variantBarPool = CreateSecureFramePool("Frame", TSP_EventFrame, "TSP_VariantBarTemplate", VariantBarResetFunc);
TSP_EventFrame.barBlockPool = CreateSecureFramePool("Frame", TSP_EventFrame, "TSP_BarBlockTemplate", BarBlockResetFunc);

function TSP_EventFrame:ADDON_LOADED(loaded)
	if (loaded == "Blizzard_Collections") then
		local scrollbox = WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBox;
		scrollbox.view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame, OnSetButtonInitialized, self);

		TSP_SetsDataProvider = CreateFromMixins(WardrobeSetsDataProviderMixin);

		TSP_EventFrame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
		
		TSP_EventFrame:UnregisterEvent("ADDON_LOADED");
	end
end

function TSP_EventFrame:TRANSMOG_COLLECTION_UPDATED()
	if TSP_SetsDataProvider then
		TSP_SetsDataProvider:ClearSets();
	end
end