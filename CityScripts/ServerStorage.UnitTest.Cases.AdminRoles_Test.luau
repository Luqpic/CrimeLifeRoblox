-- Tests for ServerScriptService.Admin.Roles.roleOf (2026-11-20): who gets a role. The environment (Studio, the
-- place's creator, the rank lookup) is injected, so no real group call is made.
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Config = require(ServerScriptService.Admin.Config)
	local Roles = require(ServerScriptService.Admin.Roles)
	local expect = t.expect

	local OTHER_GROUP = 1234

	-- ranks: { [groupId] = rank }; a rank lookup for any other group returns 0, `fails` makes every lookup throw
	local function env(fields)
		local ranks = fields.ranks or {}
		return {
			isStudio = fields.isStudio == true,
			creatorType = fields.creatorType or Enum.CreatorType.Group,
			creatorId = fields.creatorId or OTHER_GROUP,
			rankIn = function(groupId)
				if fields.fails then
					error("HTTP 500")
				end
				return ranks[groupId] or 0
			end,
		}
	end

	t.test("any Studio session is owner, without a rank lookup", function()
		expect.equal(Roles.roleOf(10, env({ isStudio = true, fails = true })), "owner")
	end)

	t.test("rank 255 in the creator group is owner", function()
		expect.equal(Roles.roleOf(10, env({ ranks = { [OTHER_GROUP] = 255 } })), "owner")
	end)

	t.test("rank 252 to 254 in the creator group is helper", function()
		expect.equal(Roles.roleOf(10, env({ ranks = { [OTHER_GROUP] = Config.HELPER_RANK } })), "helper")
		expect.equal(Roles.roleOf(10, env({ ranks = { [OTHER_GROUP] = 254 } })), "helper")
	end)

	t.test("SolarArc Studios ranks count whatever the creator", function()
		expect.equal(Roles.roleOf(10, env({ ranks = { [Config.GROUP_ID] = 255 } })), "owner")
		expect.equal(Roles.roleOf(10, env({ ranks = { [Config.GROUP_ID] = 252 } })), "helper")
		expect.equal(Roles.roleOf(10, env({ creatorType = Enum.CreatorType.User, creatorId = 99, ranks = { [Config.GROUP_ID] = 255 } })), "owner")
	end)

	t.test("the best rank wins across the two groups", function()
		expect.equal(Roles.roleOf(10, env({ ranks = { [OTHER_GROUP] = 252, [Config.GROUP_ID] = 255 } })), "owner")
	end)

	t.test("a member below 252 has no role", function()
		expect.equal(Roles.roleOf(10, env({ ranks = { [OTHER_GROUP] = 251, [Config.GROUP_ID] = 1 } })), nil)
		expect.equal(Roles.roleOf(10, env({})), nil)
	end)

	t.test("a rank lookup error gives no role and says it failed", function()
		local role, failed = Roles.roleOf(10, env({ fails = true }))
		expect.equal(role, nil)
		expect.equal(failed, true)
	end)

	t.test("a user-created place's creator is owner, anyone else needs a rank", function()
		local userPlace = { creatorType = Enum.CreatorType.User, creatorId = 77, fails = true }
		expect.equal(Roles.roleOf(77, env(userPlace)), "owner")
		expect.equal(Roles.roleOf(78, env({ creatorType = Enum.CreatorType.User, creatorId = 77 })), nil)
	end)

	t.test("the creator check only applies to a user-created place", function()
		-- a group place whose CreatorId happens to equal the player's UserId gives nothing by itself
		expect.equal(Roles.roleOf(OTHER_GROUP, env({})), nil)
	end)
end
