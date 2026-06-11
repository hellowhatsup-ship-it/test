--!strict
-- Lightweight signal implementation for Luau listener workflows.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type Listener<T...> = {
	callback: (T...) -> (),
	connected: boolean,
	connection: any?,
	next: Listener<T...>?,
	previous: Listener<T...>?,
}

type SignalState<T...> = Signal<T...> & {
	_head: Listener<T...>?,
	_waitingThreads: { thread },
	_destroyed: boolean,
}

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end

	self.Connected = false

	local listener = self._listener
	if listener == nil or not listener.connected then
		return
	end

	listener.connected = false

	local previousListener = listener.previous
	local nextListener = listener.next

	if previousListener ~= nil then
		previousListener.next = nextListener
	else
		self._signal._head = nextListener
	end

	if nextListener ~= nil then
		nextListener.previous = previousListener
	end

	listener.next = nil
	listener.previous = nil
end

function Signal.new<T...>(): Signal<T...>
	local self: SignalState<T...> = setmetatable({
		_head = nil,
		_waitingThreads = {},
		_destroyed = false,
	}, Signal) :: any

	return self
end

function Signal:Connect<T...>(callback: (T...) -> ()): Connection
	assert(type(callback) == "function", "Signal:Connect(callback) expects a function")
	assert(not self._destroyed, "Cannot connect to a destroyed Signal")

	local listener: Listener<T...> = {
		callback = callback,
		connected = true,
		connection = nil,
		next = self._head,
		previous = nil,
	}

	if self._head ~= nil then
		self._head.previous = listener
	end

	self._head = listener

	local connection = setmetatable({
		Connected = true,
		_listener = listener,
		_signal = self,
	}, Connection) :: any

	listener.connection = connection

	return connection
end

function Signal:Once<T...>(callback: (T...) -> ()): Connection
	assert(type(callback) == "function", "Signal:Once(callback) expects a function")

	local connection: Connection? = nil
	connection = self:Connect(function(...: T...)
		if connection ~= nil then
			connection:Disconnect()
		end

		callback(...)
	end)

	return connection :: Connection
end

function Signal:Wait<T...>(): T...
	assert(not self._destroyed, "Cannot wait on a destroyed Signal")

	local waitingThreads = self._waitingThreads
	waitingThreads[#waitingThreads + 1] = coroutine.running()

	return coroutine.yield()
end

function Signal:Fire<T...>(...: T...)
	if self._destroyed then
		return
	end

	local listener = self._head
	while listener ~= nil do
		local currentListener = listener
		listener = listener.next

		if currentListener.connected then
			task.spawn(currentListener.callback, ...)
		end
	end

	local waitingThreads = self._waitingThreads
	if #waitingThreads > 0 then
		self._waitingThreads = {}

		for _, waitingThread in waitingThreads do
			task.spawn(waitingThread, ...)
		end
	end
end

function Signal:DisconnectAll()
	local listener = self._head
	while listener ~= nil do
		listener.connected = false

		if listener.connection ~= nil then
			listener.connection.Connected = false
		end

		listener.previous = nil

		local nextListener = listener.next
		listener.next = nil
		listener = nextListener
	end

	self._head = nil
end

function Signal:Destroy()
	if self._destroyed then
		return
	end

	self:DisconnectAll()
	self._destroyed = true

	local waitingThreads = self._waitingThreads
	self._waitingThreads = {}

	for _, waitingThread in waitingThreads do
		task.spawn(waitingThread)
	end
end

return Signal
