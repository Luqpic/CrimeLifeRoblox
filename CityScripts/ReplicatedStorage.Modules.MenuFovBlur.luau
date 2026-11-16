-- Field-of-view + screen blur for menu-style UI (Weaponry Shop, Player Card). Routes FOV through
-- CameraAuthority as a new "Menu" source rather than writing Workspace.CurrentCamera.FieldOfView
-- directly, so this can never silently fight ADS zoom / sprint / crouch for the camera. The blur is
-- a single persistent BlurEffect (created once, not per-open) since nothing else in this game uses
-- Lighting blur yet -- no arbitration needed there, just don't leak a fresh one on every open.
--
-- Reference-counted: open()/close() may be called from more than one menu independently (nothing
-- stops a player from having both the shop and their player card open at once), so the effect only
-- actually applies on the 0->1 transition and only actually clears on the 1->0 transition -- the
-- same idea CameraAuthority itself already uses for MinZoomDistance/MaxZoomDistance.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CameraAuthority = require(ReplicatedStorage.Modules.CameraAuthority)

local MENU_FOV = 80
local BLUR_SIZE = 20
local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local blur = Instance.new("BlurEffect")
blur.Name = "MenuBlur"
blur.Size = 0
blur.Parent = Lighting

local openCount = 0

local MenuFovBlur = {}

function MenuFovBlur.open()
	openCount += 1
	if openCount > 1 then
		return
	end
	CameraAuthority.FieldOfView:Set("Menu", MENU_FOV)
	TweenService:Create(blur, TWEEN_INFO, { Size = BLUR_SIZE }):Play()
end

function MenuFovBlur.close()
	openCount = math.max(openCount - 1, 0)
	if openCount > 0 then
		return
	end
	CameraAuthority.FieldOfView:Clear("Menu")
	TweenService:Create(blur, TWEEN_INFO, { Size = 0 }):Play()
end

-- From the Robbery place (phase 3 G7, used by UiButtonEffects): open() now, and a release function
-- that calls close() exactly once, so a double release is a no-op instead of corrupting the count.
function MenuFovBlur.acquire(): () -> ()
	MenuFovBlur.open()
	local released = false
	return function()
		if released then
			return
		end
		released = true
		MenuFovBlur.close()
	end
end

return MenuFovBlur
