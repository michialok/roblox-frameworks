--// Lightweight module that creates an object which imitates a RBXScriptSignal

local Signals = {}

local yielder = game:GetService("RunService").Heartbeat

function Signals.new()
	local signal = {}
	signal.__functions = {}
	signal.__index = 0
	signal.__signals = 0
	signal.__waiting = {}
	
	function signal:Connect(func: (any) -> (any))
		signal.__signals += 1
		
		local index = signal.__signals
		signal.__functions[index] = func
		
		local connection = {}
		
		function connection:Disconnect()
			signal.__functions[index] = nil
		end

		return connection
	end
	
	function signal:Once(func: (any) -> (any))
		local connection
		connection = signal:Connect(function(...)
			connection:Disconnect()
			func(...)
		end)
		
		return connection
	end
	
	function signal:Fire(...)
		if signal.__waiting[signal.__index] then
			signal.__waiting[signal.__index] = table.pack(...)
		end
		
		signal.__index += 1

		local args = table.pack(...)
		for _, func in signal.__functions do
			task.spawn(func, unpack(args))
		end
	end

	function signal:Wait()
		local oldIndex = signal.__index
		signal.__waiting[oldIndex] = true

		repeat
			yielder:Wait()
		until oldIndex ~= signal.__index
		
		local args = table.clone(signal.__waiting[oldIndex])
		
		task.defer(function()
			signal.__waiting[oldIndex] = nil
		end)
		
		return unpack(args)
	end
	
	return signal
end

return Signals
