local addonName = "BetterWardrobe";
if (not C_AddOns.IsAddOnLoadable(addonName)) then return; end

local ExternalMixin = {};

local initialized = false;

function ExternalMixin:Initialize(betterWardrobe, tsp)
	if (initialized or not BetterWardrobeCollectionFrame) then
		return;
	end
	initialized = true;

	local function WrapperInitializedButton(source, button, data)
		if (BetterWardrobeCollectionFrame:CheckTab(self.betterWardrobe.Globals.TAB_SAVED_SETS)) then
			-- Don't show bar in the saved tab. It's setIDs are bogus
			if (button.TSPBar) then
				button.TSPBar:Hide();
			end
			return;
		end
		tsp:OnSetButtonInitialized(button, data)
	end

	BetterWardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBox.view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame, WrapperInitializedButton, self);
	
	-- Use the addon's dataprovider. It's compatible and contains the data for the extra sets it provides
	tsp.SetsDataProvider = betterWardrobe.SetsDataProvider;

	-- Fix a sorting issue with the addon's dataprovider so variants don't switch positions contstantly
	local originalWrapper = tsp.WrapperGetVariantSets;
	tsp.WrapperGetVariantSets = function(source, setID, table)
			originalWrapper(source, setID, table);
			WardrobeSetsDataProviderMixin.SortSets(nil, table, true, true);
		end
end

function ExternalMixin:GetAddonName()
	return addonName;
end

function ExternalMixin:OnLoad(tsp)
	self.betterWardrobe = LibStub("AceAddon-3.0"):GetAddon("BetterWardrobe");

	hooksecurefunc(self.betterWardrobe.Init, "LoadModules", function() self:Initialize(self.betterWardrobe, tsp); end);
end

TSP_CoreFrame:ProvideExternal(ExternalMixin);