-- Starts WantedService and steps its drain twice a second (police and wanted, Task 1, 2026-11-17).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Wanted.Constants)
local WantedService = require(script.Parent.WantedService)

WantedService.start()

while true do
	task.wait(1 / Constants.SEEN_CHECK_HZ)
	WantedService._step()
end
