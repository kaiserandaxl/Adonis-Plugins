local Ranks = {
	-- Can be the Rank Level or the Rank Name. E.g. 100 or "Moderators"
	-- If you put a "-" before it will include everything BELOW it aswell
};

local Error = false -- If true will warn they can't run and not run, if false it will run just on themself only. Will still warn if nobody was selected

return function(Vargs)
	local server = Vargs.Server;
	local service = Vargs.Service;

	local Settings = server.Settings
	local Functions, Commands, Admin, Anti, Core, HTTP, Logs, Remote, Process, Variables, Deps =
		server.Functions, server.Commands, server.Admin, server.Anti, server.Core, server.HTTP, server.Logs, server.Remote, server.Process, server.Variables, server.Deps


	service.GetPlayers = function(plr, argument, options)
		options = options or {}

		local parent = options.Parent or service.Players
		local players = {}
		local delplayers = {}
		local addplayers = {}
		local randplayers = {}

		local function getplr(p)
			if p then
				if p.ClassName == "Player" then
					return p
				elseif p:IsA("NetworkReplicator") then
					local networkPeerPlayer = p:GetPlayer()
					if networkPeerPlayer and networkPeerPlayer.ClassName == "Player" then
						return networkPeerPlayer
					end
				end
			end
			return nil
		end

		local function checkMatch(msg)
			msg = string.lower(msg)
			local doReturn
			local PlrLevel = if plr then Admin.GetLevel(plr) else 0

			for _, data in Functions.PlayerFinders do
				if not data.Level or (data.Level and PlrLevel >= data.Level) then
					local check = ((data.Prefix and Settings.SpecialPrefix) or "")..data.Match
					if (data.Absolute and msg == check) or (not data.Absolute and string.sub(msg, 1, #check) == string.lower(check)) then
						if data.Absolute then
							return data
						else --// Prioritize absolute matches over non-absolute matches
							doReturn = data
						end
					end
				end
			end

			return doReturn
		end

		if plr == nil then
			--// Select all players
			for _, v in parent:GetChildren() do
				local p = getplr(v)
				if p then
					table.insert(players, p)
				end
			end
		elseif plr and not argument then
			--// Default to the executor ("me")
			return {plr}
		else
			if string.match(argument, "^##") then
				error(`String passed to GetPlayers is filtered: {argument}`, 2)
			end

			local selectors = string.gmatch(argument, "([^,]+)")

			--// This is for player commands that take in service.GetPlayers() to make sure someone isnt passing in a message that is insanely long
			local PlrLevel = if plr then Admin.GetLevel(plr) else 0
			local AllowUnsafeSelectors = PlrLevel > 0 or options.AllowUnsafeSelectors
			local MaxSelectors = Variables.MaxSafeSelectors or 400 -- 400 seems like a good "max" that won't ever be reached

			local index = 0

			for s in selectors do
				index += 1
				if not AllowUnsafeSelectors and index > MaxSelectors then
					break
				end
				local plrCount = 0
				local function plus() plrCount += 1 end

				if not options.NoSelectors then
					local matchFunc = checkMatch(s)
					if matchFunc then
						matchFunc.Function(
							s,
							plr,
							parent,
							players,
							delplayers,
							addplayers,
							randplayers,
							getplr,
							plus,
							options.IsKicking,
							options.IsServer,
							options.DontError,
							not options.NoFakePlayer,
							options.AllowUnknownUsers
						)
					end
				end

				if plrCount == 0 then
					--// Check for display names
					for _, v in parent:GetChildren() do
						local p = getplr(v)
						if p and p.ClassName == "Player" and string.match(string.lower(p.DisplayName), `^{service.SanitizePattern(string.lower(s))}`) then
							table.insert(players, p)
							plus()
						end
					end

					if plrCount == 0 then
						--// Check for usernames
						for _, v in parent:GetChildren() do
							local p = getplr(v)
							if p and p.ClassName == "Player" and string.match(string.lower(p.Name), `^{service.SanitizePattern(string.lower(s))}`) then
								table.insert(players, p)
								plus()
							end
						end

						--// Check for user IDs
						if tonumber(s) then
							for _, v in parent:GetChildren() do
								local p = getplr(v)
								if p and p.ClassName == "Player" and p.UserId == tonumber(s) then
									table.insert(players, p)
									plus()
								end
							end
						end

						if plrCount == 0 then
							if not options.NoFakePlayer then
								--// Attempt to retrieve non-ingame user
								local UserId
								if Functions.GetUserIdFromNameAsync(s) then
									UserId = Functions.GetUserIdFromNameAsync(s)
								else
									if tonumber(s) then
										UserId = s
									end
								end
								if UserId or options.AllowUnknownUsers then
									table.insert(players, Functions.GetFakePlayer({
										Name = s;
										DisplayName = s;
										UserId = if UserId then UserId else -1;
									}))
									plus()
								end
							end

							if plrCount == 0 and not options.DontError then
								Remote.MakeGui(plr, "Output", {
									Title = "Missing player";
									Message = if not options.NoFakePlayer then `No user named '{s}' exists`
										else `No players matching '{s}' were found!`;
								})
							end
						end
					end
				end
			end
		end

		--// The following is intended to prevent name spamming (eg. :re scel,scel,scel,scel,scel,scel,scel,scel,scel,scel,scel,scel,scel,scel...)
		--// It will also prevent situations where a player falls within multiple player finders (eg. :re group-1928483,nonadmins,radius-50 (one player can match all 3 of these))
		--// Edited to adjust removals and randomizers.

		local filteredList = {}
		local checkList = {}

		for _, v in players do
			if not checkList[v] then
				table.insert(filteredList, v)
				checkList[v] = true
			end
		end

		local delFilteredList = {}
		local delCheckList = {}

		for _, v in delplayers do
			if not delCheckList[v] then
				table.insert(delFilteredList, v)
				delCheckList[v] = true
			end
		end

		local addFilteredList = {}
		local addCheckList = {}

		for _, v in addplayers do
			if not addCheckList[v] then
				table.insert(addFilteredList, v)
				addCheckList[v] = true
			end
		end

		local removalSuccessList = {}

		for i, v in filteredList do
			for j, w in delFilteredList do
				if v.Name == w.Name then
					table.remove(filteredList,i)
					table.insert(removalSuccessList, w)
				end
			end
		end


		for j, w in addFilteredList do
			table.insert(filteredList, w)
		end

		local checkList2 = {}
		local finalFilteredList = {}

		for _, v in filteredList do
			if not checkList2[v] then
				table.insert(finalFilteredList, v)
				checkList2[v] = true
			end
		end


		local comboTableCheck = {}

		for _, v in finalFilteredList do
			table.insert(comboTableCheck, v)
		end
		for _, v in delFilteredList do
			table.insert(comboTableCheck, v)
		end

		local function rplrsort()
			local children = parent:GetChildren()
			local childcount = #children
			local excludecount = #comboTableCheck
			if excludecount < childcount then
				local rand = children[math.random(#children)]
				local rp = getplr(rand)

				for _, v in comboTableCheck do
					if v.Name == rp.Name then
						rplrsort()
						return
					end
				end

				table.insert(finalFilteredList, rp)

				local comboTableCheck = {}
				for _, v in finalFilteredList do
					table.insert(comboTableCheck, v)
				end
				for _, v in delFilteredList do
					table.insert(comboTableCheck, v)
				end
			end
		end

		for i, v in randplayers do
			rplrsort()
		end
		
		local Level, Rank = Admin.GetLevel(plr)
		
		local function Found()
			if Error then
				error("You can only run commands on yourself!")
			else
				for i,v in pairs(finalFilteredList) do if v ~= plr then table.remove(finalFilteredList,i)
						if #finalFilteredList == 0 then error("You can only run commands on yourself!") end
					end end
			end
		end
		
		for i,v in Ranks do
			if type(v) == "string" and (not tonumber(v)) then
				if v:match("^-") then
					v = Settings.Ranks[v:gsub("^-","",1)].Level
					if Level <= v then
						Found()
					end
				else
					if Level == Settings.Ranks[v].Level then
						Found()
					end
				end
			else
				v = tonumber(v)
				if v > 0 then
					if Level == v then
						Found()
					end
				else
					if Level <= math.abs(v) then
						Found()
					end
				end
			end
		end

		return finalFilteredList
	end;
end
