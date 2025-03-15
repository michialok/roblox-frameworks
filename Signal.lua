--// Lightweight module that creates an object which imitates a RBXScriptSignal

local Signals = {}

local yielder = game:GetService("RunService").Heartbeat

function Signals.new()
	local signal = {}
	signal._functions = {}
	signal._index = 0
	signal._signals = 0
	signal._waiting = {}
	
	function signal:Connect(func: (any) -> (any))
		signal._signals += 1
		
		local index = signal._signals
		signal._functions[index] = func
		
		local connection = {}
		
		function connection:Disconnect()
			signal._functions[index] = nil
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
		if signal._waiting[signal._index] then
			signal._waiting[signal._index] = table.pack(...)
		end
		
		signal._index += 1

		local args = table.pack(...)
		for _, func in signal._functions do
			task.spawn(func, unpack(args))
		end
	end

	function signal:Wait()
		local oldIndex = signal._index
		signal._waiting[oldIndex] = true

		repeat
			yielder:Wait()
		until oldIndex ~= signal._index
		
		local args = table.clone(signal._waiting[oldIndex])
		
		task.defer(function()
			signal._waiting[oldIndex] = nil
		end)
		
		return unpack(args)
	end
	
	return signal
end

return Signals
