-- WoW shows a StaticPopup for ADDON_ACTION_FORBIDDEN / ADDON_ACTION_BLOCKED via UIParent's event handler.
-- Unregistering the events on UIParent removes the dialog; the forbidden call is still refused (nothing unsafe happens).
UIParent:UnregisterEvent("ADDON_ACTION_FORBIDDEN")
UIParent:UnregisterEvent("ADDON_ACTION_BLOCKED")
