--!strict
-- PropertyAuthority: generic conflict-arbitration engine for a single Roblox property that
-- multiple independent systems want to drive (e.g. Camera.FieldOfView, Humanoid.CameraOffset).
-- Callers register the value they want under a source id instead of writing the property
-- directly; this module resolves the winner by an explicit priority order (highest priority
-- first) and calls the supplied `applier` exactly once whenever the resolved value changes.
--
-- Usage:
--   local authority = PropertyAuthority.new(defaultValue, {"HighPrioritySource", "LowPrioritySource"}, function(value)
--       SomeInstance.SomeProperty = value
--   end)
--   authority:Set("HighPrioritySource", someValue)   -- registers/updates a desired value
--   authority:Clear("HighPrioritySource")             -- removes a source's contribution

local PropertyAuthority = {}
PropertyAuthority.__index = PropertyAuthority

export type Applier = (value: any, source: string?) -> ()

function PropertyAuthority.new(defaultValue: any, priorityOrder: { string }, applier: Applier)
	local self = setmetatable({}, PropertyAuthority)
	self._defaultValue = defaultValue
	self._priorityOrder = priorityOrder
	self._applier = applier
	self._values = {} :: { [string]: any }
	self._currentSource = nil :: string?
	self._lastAppliedValue = defaultValue
	return self
end

-- Registers (or updates) the value a source wants applied. Applies immediately if this
-- changes the winning source or the winning source's value.
function PropertyAuthority:Set(source: string, value: any)
	self._values[source] = value
	self:_resolve()
end

-- The value a source has registered, or nil (2026-11-20: ShoulderCamera folds Crouch's offset into its own).
function PropertyAuthority:Get(source: string): any
	return self._values[source]
end

-- Removes a source's contribution. If it was the active winner, the next highest-priority
-- remaining source (or the default) takes over immediately. Safe to call on a source that
-- was never set.
function PropertyAuthority:Clear(source: string)
	if self._values[source] == nil then
		return
	end
	self._values[source] = nil
	self:_resolve()
end

function PropertyAuthority:_resolve()
	for _, source in self._priorityOrder do
		local value = self._values[source]
		if value ~= nil then
			if source ~= self._currentSource or value ~= self._lastAppliedValue then
				self._currentSource = source
				self._lastAppliedValue = value
				self._applier(value, source)
			end
			return
		end
	end

	if self._currentSource ~= nil or self._lastAppliedValue ~= self._defaultValue then
		self._currentSource = nil
		self._lastAppliedValue = self._defaultValue
		self._applier(self._defaultValue)
	end
end

return PropertyAuthority
