-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.A-Chassis Interface.Handbrake.LocalScript ; copies: 1 ; Adler-32: 621a4798
script.Parent.Visible = script.Parent.Parent.Values.PBrake.Value
script.Parent.Parent.Values.PBrake.Changed:connect(function()
  script.Parent.Visible = script.Parent.Parent.Values.PBrake.Value
end)
