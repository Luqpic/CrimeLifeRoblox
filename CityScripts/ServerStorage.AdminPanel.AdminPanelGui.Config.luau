-- Admin panel client numbers (2026-11-20). The server's live in ServerScriptService.Admin.Config; the server
-- re-checks every value these steppers produce.
return table.freeze({
	TOGGLE_KEY = Enum.KeyCode.F2,
	PANEL_SIZE = Vector2.new(760, 480),
	FIT_MARGIN = 16, -- px kept free round the panel inside the safe area
	CALL_SPACING = 0.3, -- s between two remote calls (the server refuses calls under 0.25 s apart)
	CONFIRM_SECONDS = 3, -- a kick or ban needs its second click within this
	STATS_SECONDS = 2, -- the Server tab's stats refresh while that tab is shown
	FLY_SPEED = 60,
	FLY_RESPONSIVENESS = 50, -- AlignOrientation: how fast the body turns to the camera's heading
	-- stepper rows: step, lowest, highest
	STEPPERS = table.freeze({
		LevelRow = table.freeze({ 1, 1, 70 }),
		CashRow = table.freeze({ 1000, 1, 1000000 }),
		SprayRow = table.freeze({ 100, 1, 1000000 }),
		Police = table.freeze({ 1, 1, 6 }),
		Enemies = table.freeze({ 1, 1, 6 }),
		Speed = table.freeze({ 5, 8, 100 }),
	}),
})
