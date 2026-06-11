--!strict
-- Reusable Roblox inserter module with lifecycle signals for game systems.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Signal = require(script.Parent.Signal)

export type InsertOptions = {
	parent: Instance?,
	name: string?,
	cframe: CFrame?,
	position: Vector3?,
	attributes: { [string]: any }?,
	properties: { [string]: any }?,
	tags: { string }?,
	onInserted: ((Instance, InsertRecord) -> ())?,
}

export type InsertRecord = {
	id: string,
	key: string,
	instance: Instance,
	template: Instance,
	createdAt: number,
	Destroy: (self: InsertRecord) -> (),
}

export type Inserter = {
	Inserted: any,
	Removing: any,
	Removed: any,
	Registered: any,
	Register: (self: Inserter, key: string, template: Instance) -> Instance,
	RegisterFolder: (self: Inserter, folder: Instance, overwrite: boolean?) -> (),
	GetTemplate: (self: Inserter, key: string) -> Instance?,
	Insert: (self: Inserter, key: string, options: InsertOptions?) -> InsertRecord,
	InsertMany: (self: Inserter, key: string, count: number, options: InsertOptions?) -> { InsertRecord },
	Remove: (self: Inserter, idOrInstance: string | Instance) -> boolean,
	Clear: (self: Inserter) -> (),
	Get: (self: Inserter, id: string) -> InsertRecord?,
	GetAll: (self: Inserter) -> { InsertRecord },
	Destroy: (self: Inserter) -> (),
}

type InserterState = Inserter & {
	_templates: { [string]: Instance },
	_records: { [string]: InsertRecord },
	_destroyed: boolean,
}

local Inserter = {}
Inserter.__index = Inserter

local function makeId(): string
	return HttpService:GenerateGUID(false)
end

local function copyOptions(options: InsertOptions?): InsertOptions
	return options or {}
end

local function applyPlacement(instance: Instance, options: InsertOptions)
	local model = instance :: any

	if options.cframe ~= nil then
		if instance:IsA("Model") then
			model:PivotTo(options.cframe)
		elseif instance:IsA("BasePart") then
			model.CFrame = options.cframe
		end
	elseif options.position ~= nil then
		if instance:IsA("Model") then
			model:PivotTo(CFrame.new(options.position))
		elseif instance:IsA("BasePart") then
			model.Position = options.position
		end
	end
end

local function applyMetadata(instance: Instance, options: InsertOptions)
	if options.name ~= nil then
		instance.Name = options.name
	end

	if options.attributes ~= nil then
		for attributeName, attributeValue in options.attributes do
			instance:SetAttribute(attributeName, attributeValue)
		end
	end

	if options.properties ~= nil then
		local editableInstance = instance :: any
		for propertyName, propertyValue in options.properties do
			editableInstance[propertyName] = propertyValue
		end
	end

	if options.tags ~= nil then
		for _, tag in options.tags do
			CollectionService:AddTag(instance, tag)
		end
	end
end

local function createRecord(self: InserterState, key: string, template: Instance, instance: Instance): InsertRecord
	local recordId = makeId()
	local record: InsertRecord

	record = {
		id = recordId,
		key = key,
		instance = instance,
		template = template,
		createdAt = os.clock(),
		Destroy = function(recordSelf: InsertRecord)
			self:Remove(recordSelf.id)
		end,
	}

	self._records[recordId] = record
	instance:SetAttribute("InserterId", recordId)
	instance:SetAttribute("InserterKey", key)

	return record
end

function Inserter.new(): Inserter
	local self: InserterState = setmetatable({
		_templates = {},
		_records = {},
		_destroyed = false,
		Inserted = Signal.new(),
		Removing = Signal.new(),
		Removed = Signal.new(),
		Registered = Signal.new(),
	}, Inserter) :: any

	return self
end

function Inserter:Register(key: string, template: Instance): Instance
	assert(not self._destroyed, "Cannot register templates on a destroyed Inserter")
	assert(type(key) == "string" and key ~= "", "Inserter:Register(key, template) needs a non-empty key")
	assert(typeof(template) == "Instance", "Inserter:Register(key, template) needs an Instance template")

	self._templates[key] = template
	self.Registered:Fire(key, template)

	return template
end

function Inserter:RegisterFolder(folder: Instance, overwrite: boolean?)
	assert(typeof(folder) == "Instance", "Inserter:RegisterFolder(folder) needs an Instance folder")

	for _, child in folder:GetChildren() do
		if overwrite or self._templates[child.Name] == nil then
			self:Register(child.Name, child)
		end
	end
end

function Inserter:GetTemplate(key: string): Instance?
	return self._templates[key]
end

function Inserter:Insert(key: string, options: InsertOptions?): InsertRecord
	assert(not self._destroyed, "Cannot insert with a destroyed Inserter")

	local template = self._templates[key]
	assert(template ~= nil, `No template registered for key "{key}"`)

	local safeOptions = copyOptions(options)
	local instance = template:Clone()
	local parent = safeOptions.parent or workspace
	local record = createRecord(self, key, template, instance)

	applyMetadata(instance, safeOptions)
	applyPlacement(instance, safeOptions)

	instance.Parent = parent
	self.Inserted:Fire(record, instance)

	if safeOptions.onInserted ~= nil then
		safeOptions.onInserted(instance, record)
	end

	return record
end

function Inserter:InsertMany(key: string, count: number, options: InsertOptions?): { InsertRecord }
	assert(count >= 0, "Inserter:InsertMany(key, count) needs a non-negative count")

	local records = table.create(count)
	for index = 1, count do
		records[index] = self:Insert(key, options)
	end

	return records
end

function Inserter:Get(id: string): InsertRecord?
	return self._records[id]
end

function Inserter:GetAll(): { InsertRecord }
	local records = {}
	for _, record in self._records do
		records[#records + 1] = record
	end

	return records
end

function Inserter:Remove(idOrInstance: string | Instance): boolean
	local record: InsertRecord? = nil

	if typeof(idOrInstance) == "Instance" then
		local inserterId = idOrInstance:GetAttribute("InserterId")
		if type(inserterId) == "string" then
			record = self._records[inserterId]
		end
	else
		record = self._records[idOrInstance]
	end

	if record == nil then
		return false
	end

	self.Removing:Fire(record, record.instance)
	self._records[record.id] = nil

	if record.instance.Parent ~= nil then
		record.instance:Destroy()
	end

	self.Removed:Fire(record)
	return true
end

function Inserter:Clear()
	local records = self:GetAll()
	for _, record in records do
		self:Remove(record.id)
	end
end

function Inserter:Destroy()
	if self._destroyed then
		return
	end

	self:Clear()
	self._destroyed = true

	self.Inserted:Destroy()
	self.Removing:Destroy()
	self.Removed:Destroy()
	self.Registered:Destroy()
	table.clear(self._templates)
end

return Inserter
