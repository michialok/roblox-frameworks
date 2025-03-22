--// A safe implementation of an object which imitates Remote Functions using Remote Events to avoid infinite yielding or errors
--// This Remote Function Imitation isn't any slower than the traditional Remote Function

--[[ Example Code

local remoteFunctionObject = remoteFunctionModule.new(remoteEvent)

remoteFunctionObject.onClientEvent = function(cat)
	return string.format("Hello from the Client, %s!", cat)
end

local greetingFromServer = remoteFunctionObject:invokeServer("michialok")

print(greetingFromServer) -> "Hello from the Server, michialok!"

--]]

local remoteFunction = {}
remoteFunction.allRemoteFunctionObjects = {}

local runService = game:GetService("RunService")

local actionTypes = {}
actionTypes.requesting = "__REQUESTING__"
actionTypes.receiving = "__RECEIVING__"

type actionTypes = "__REQUESTING__"|"__RECEIVING__"

-- Initialize the server
if runService:IsServer() then
	local function playerRemoving(player: Player)
		-- Check if player had any open remote function requests
		-- Go through every remote function object first
		for _, remoteFunctionObject in remoteFunction.allRemoteFunctionObjects do
			-- Now, go through its open requests
			for index, isWaitingForPlayer in remoteFunctionObject.__openRequests do
				if not isWaitingForPlayer then continue end

				-- If the object is still waiting, remove the player from the remote function request and return empty
				remoteFunctionObject.__openRequests[index] = nil
				remoteFunctionObject.__results[index] = {}
			end
		end
	end

	game.Players.PlayerRemoving:Connect(playerRemoving)
end

-- Fresh Remote Function Object
function remoteFunction.__getObject(remoteEvent: RemoteEvent)
	local remoteFunctionObject = {}
	remoteFunctionObject.__openRequests = {}
	remoteFunctionObject.__results = {}
	remoteFunctionObject.__countIndex = 0
	remoteFunctionObject.timeout = 15

	local connections = {}

	if runService:IsServer() then
		-- Server Remote Function Object
		remoteFunctionObject.onServerInvoke = function(player: Player) end :: (Player, any) -> (any)

		-- Server receives a request from the client
		local onServerConnection = remoteEvent.OnServerEvent:Connect(function(player: Player, index: number, ACTION_TYPE: actionTypes, ...)
			if ACTION_TYPE == actionTypes.requesting then -- __REQUESTING__
				-- Client requests from server
				-- Send server response back to client with code __RECEIVING__
				remoteEvent:FireClient(player, index, actionTypes.receiving, remoteFunctionObject.onServerInvoke(player, ...))
			elseif ACTION_TYPE == actionTypes.receiving then -- __RECEIVING__
				-- Client sends response to server invoked by server
				-- Make sure the request isn't closed yet
				if remoteFunctionObject.__openRequests[index] == nil then return end

				remoteFunctionObject.__results[index] = table.pack(...)
				remoteFunctionObject.__openRequests[index] = nil
			end
		end)

		table.insert(connections, onServerConnection)

		function remoteFunctionObject:invokeClient(player: Player, ...)
			-- Increase count index by 1
			remoteFunctionObject.__countIndex += 1
			local currentIndex = remoteFunctionObject.__countIndex
			remoteFunctionObject.__openRequests[currentIndex] = true -- true = server request

			-- Send client a request with requestId(currentIndex), __REQUESTING__, and given args
			remoteEvent:FireClient(player, currentIndex, actionTypes.requesting, ...)

			local begin = tick()

			-- Now, we wait for a response or the timeout
			repeat
				runService.Heartbeat:Wait()
			until remoteFunctionObject.__results[currentIndex] or (tick() - begin) >= remoteFunctionObject.timeout

			local results = remoteFunctionObject.__results[currentIndex]

			local unpackedResults = unpack(results or {})

			remoteFunctionObject.__results[currentIndex] = nil

			-- Return response
			return unpackedResults
		end
	else 
		-- Client Remote Function Object
		remoteFunctionObject.onClientInvoke = function() end :: (any) -> (any)

		-- Client receives a request from the server
		local onClientConnection = remoteEvent.OnClientEvent:Connect(function(index: number, ACTION_TYPE: actionTypes, ...)
			if ACTION_TYPE == actionTypes.requesting then -- __REQUESTING__
				-- Server requests from client
				-- Send client response back to server with code __RECEIVING__
				remoteEvent:FireServer(index, actionTypes.receiving, remoteFunctionObject.onClientInvoke(...))
			elseif ACTION_TYPE == actionTypes.receiving then -- __RECEIVING__
				-- Server sends response for client invoked by client
				-- Make sure the open request isn't closed yet
				if remoteFunctionObject.__openRequests[index] == nil then return end 

				remoteFunctionObject.__results[index] = table.pack(...)
				remoteFunctionObject.__openRequests[index] = nil
			end
		end)

		table.insert(connections, onClientConnection)

		function remoteFunctionObject:invokeServer(...)
			-- Increment count index by 1
			remoteFunctionObject.__countIndex += 1
			local currentIndex = remoteFunctionObject.__countIndex
			remoteFunctionObject.__openRequests[currentIndex] = false -- false = client request

			-- Send server a request with requestId(currentIndex), __REQUESTING__, and given args
			remoteEvent:FireServer(currentIndex, actionTypes.requesting, ...)

			local begin = tick()

			-- Now, we wait for a response or the timeout
			repeat
				runService.Heartbeat:Wait()
			until remoteFunctionObject.__results[currentIndex] or (tick() - begin) >= remoteFunctionObject.timeout

			local unpackedResults = unpack(remoteFunctionObject.__results[currentIndex] or {})

			remoteFunctionObject.__results[currentIndex] = nil

			-- Return response
			return unpackedResults
		end
	end

	function remoteFunctionObject:Destroy()
		-- Destroy the remote function object completely

		remoteFunction.allRemoteFunctionObjects[remoteEvent] = nil

		for _, connection in connections do
			connection:Disconnect()
		end

		-- Make sure all open requests are properly closed
		for index in remoteFunctionObject.__results do
			remoteFunctionObject.__results[index] = {}
		end

		task.defer(function()
			-- After all open requests have been closed, now actually destroy the remote function object
			remoteFunctionObject = nil
		end)
	end

	return remoteFunctionObject
end

function remoteFunction.new(remoteEvent: RemoteEvent): typeof(remoteFunction.__getObject(remoteEvent))
	-- If remote function object already exists, then return the existing remote function object
	if remoteFunction.allRemoteFunctionObjects[remoteEvent] then
		return remoteFunction.allRemoteFunctionObjects[remoteEvent]
	end

	-- Return fresh remote function object
	remoteFunction.allRemoteFunctionObjects[remoteEvent] = remoteFunction.__getObject(remoteEvent)

	return remoteFunction.allRemoteFunctionObjects[remoteEvent]
end

return remoteFunction
