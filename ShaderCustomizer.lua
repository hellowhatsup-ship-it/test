--!strict
-- Roblox post-processing shader customizer.
-- Drop this ModuleScript next to Signal.lua, or keep both files in a GitHub folder and sync them into Roblox.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Signal = require(script.Parent.Signal)

export type Dictionary = { [string]: any }

export type EffectConfig = {
	className: string?,
	enabled: boolean?,
	properties: Dictionary?,
}

export type ShaderSettings = {
	lighting: Dictionary?,
	effects: { [string]: EffectConfig }?,
}

export type ApplyOptions = {
	tween: boolean?,
	tweenInfo: TweenInfo?,
	clearUnusedEffects: boolean?,
}

export type ShaderCustomizerOptions = {
	prefix: string?,
	defaultTweenInfo: TweenInfo?,
	captureOriginalState: boolean?,
}

export type ShaderCustomizer = {
	Changed: any,
	PresetApplied: any,
	EffectChanged: any,
	Restored: any,
	Destroyed: any,
	Apply: (self: ShaderCustomizer, settings: ShaderSettings, options: ApplyOptions?) -> (),
	ApplyPreset: (self: ShaderCustomizer, presetName: string, options: ApplyOptions?) -> (),
	SetLighting: (self: ShaderCustomizer, properties: Dictionary, options: ApplyOptions?) -> (),
	SetEffect: (self: ShaderCustomizer, effectName: string, className: string, properties: Dictionary?, enabled: boolean?, options: ApplyOptions?) -> Instance,
	GetEffect: (self: ShaderCustomizer, effectName: string) -> Instance?,
	CaptureState: (self: ShaderCustomizer) -> ShaderSettings,
	Restore: (self: ShaderCustomizer, state: ShaderSettings?, options: ApplyOptions?) -> (),
	ClearEffects: (self: ShaderCustomizer) -> (),
	Destroy: (self: ShaderCustomizer) -> (),
}

type ShaderCustomizerState = ShaderCustomizer & {
	_prefix: string,
	_defaultTweenInfo: TweenInfo,
	_originalState: ShaderSettings,
	_effects: { [string]: Instance },
	_destroyed: boolean,
}

local ShaderCustomizer = {}
ShaderCustomizer.__index = ShaderCustomizer

local DEFAULT_PREFIX = "ShaderCustomizer_"
local DEFAULT_TWEEN_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local EFFECT_CLASSES: { [string]: boolean } = {
	Atmosphere = true,
	BloomEffect = true,
	BlurEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
	SunRaysEffect = true,
}

local LIGHTING_PROPERTIES = {
	"Ambient",
	"Brightness",
	"ClockTime",
	"ColorShift_Bottom",
	"ColorShift_Top",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
	"FogColor",
	"FogEnd",
	"FogStart",
	"GeographicLatitude",
	"GlobalShadows",
	"OutdoorAmbient",
	"ShadowSoftness",
}

local EFFECT_PROPERTIES: { [string]: { string } } = {
	Atmosphere = { "Color", "Decay", "Density", "Glare", "Haze", "Offset" },
	BloomEffect = { "Enabled", "Intensity", "Size", "Threshold" },
	BlurEffect = { "Enabled", "Size" },
	ColorCorrectionEffect = { "Brightness", "Contrast", "Enabled", "Saturation", "TintColor" },
	DepthOfFieldEffect = { "Enabled", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity" },
	SunRaysEffect = { "Enabled", "Intensity", "Spread" },
}

local PRESETS: { [string]: ShaderSettings } = {
	Clean = {
		lighting = {
			Ambient = Color3.fromRGB(138, 138, 138),
			Brightness = 2,
			ClockTime = 14,
			ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
			ColorShift_Top = Color3.fromRGB(0, 0, 0),
			EnvironmentDiffuseScale = 0,
			EnvironmentSpecularScale = 0,
			ExposureCompensation = 0,
			FogColor = Color3.fromRGB(192, 192, 192),
			FogEnd = 100000,
			FogStart = 0,
			GlobalShadows = true,
			OutdoorAmbient = Color3.fromRGB(128, 128, 128),
			ShadowSoftness = 0.2,
		},
		effects = {},
	},

	Cinematic = {
		lighting = {
			Ambient = Color3.fromRGB(85, 74, 66),
			Brightness = 2.25,
			ClockTime = 17.35,
			EnvironmentDiffuseScale = 0.45,
			EnvironmentSpecularScale = 0.7,
			ExposureCompensation = -0.08,
			FogColor = Color3.fromRGB(255, 214, 178),
			FogEnd = 850,
			FogStart = 85,
			OutdoorAmbient = Color3.fromRGB(116, 94, 82),
			ShadowSoftness = 0.55,
		},
		effects = {
			Color = {
				className = "ColorCorrectionEffect",
				enabled = true,
				properties = {
					Brightness = 0.02,
					Contrast = 0.18,
					Saturation = -0.08,
					TintColor = Color3.fromRGB(255, 232, 211),
				},
			},
			Bloom = {
				className = "BloomEffect",
				enabled = true,
				properties = { Intensity = 0.25, Size = 42, Threshold = 1.15 },
			},
			SunRays = {
				className = "SunRaysEffect",
				enabled = true,
				properties = { Intensity = 0.075, Spread = 0.82 },
			},
			Depth = {
				className = "DepthOfFieldEffect",
				enabled = true,
				properties = { FarIntensity = 0.18, FocusDistance = 72, InFocusRadius = 55, NearIntensity = 0.05 },
			},
			Atmosphere = {
				className = "Atmosphere",
				enabled = true,
				properties = {
					Color = Color3.fromRGB(255, 221, 191),
					Decay = Color3.fromRGB(111, 82, 61),
					Density = 0.28,
					Glare = 0.18,
					Haze = 1.35,
					Offset = 0.2,
				},
			},
		},
	},

	Vibrant = {
		lighting = {
			Ambient = Color3.fromRGB(105, 118, 150),
			Brightness = 2.8,
			ClockTime = 13.2,
			EnvironmentDiffuseScale = 0.75,
			EnvironmentSpecularScale = 0.85,
			ExposureCompensation = 0.08,
			FogEnd = 2500,
			FogStart = 280,
			OutdoorAmbient = Color3.fromRGB(145, 152, 172),
			ShadowSoftness = 0.35,
		},
		effects = {
			Color = {
				className = "ColorCorrectionEffect",
				enabled = true,
				properties = {
					Brightness = 0.05,
					Contrast = 0.12,
					Saturation = 0.35,
					TintColor = Color3.fromRGB(244, 250, 255),
				},
			},
			Bloom = {
				className = "BloomEffect",
				enabled = true,
				properties = { Intensity = 0.18, Size = 30, Threshold = 1.35 },
			},
			SunRays = {
				className = "SunRaysEffect",
				enabled = true,
				properties = { Intensity = 0.045, Spread = 0.72 },
			},
		},
	},

	Dreamy = {
		lighting = {
			Ambient = Color3.fromRGB(128, 111, 160),
			Brightness = 2.05,
			ClockTime = 16.1,
			EnvironmentDiffuseScale = 0.55,
			EnvironmentSpecularScale = 0.6,
			ExposureCompensation = 0.05,
			FogColor = Color3.fromRGB(211, 191, 255),
			FogEnd = 720,
			FogStart = 45,
			OutdoorAmbient = Color3.fromRGB(152, 125, 180),
			ShadowSoftness = 0.75,
		},
		effects = {
			Color = {
				className = "ColorCorrectionEffect",
				enabled = true,
				properties = {
					Brightness = 0.06,
					Contrast = -0.02,
					Saturation = 0.16,
					TintColor = Color3.fromRGB(238, 220, 255),
				},
			},
			Bloom = {
				className = "BloomEffect",
				enabled = true,
				properties = { Intensity = 0.42, Size = 56, Threshold = 0.95 },
			},
			Blur = {
				className = "BlurEffect",
				enabled = true,
				properties = { Size = 1.5 },
			},
			Atmosphere = {
				className = "Atmosphere",
				enabled = true,
				properties = {
					Color = Color3.fromRGB(220, 202, 255),
					Decay = Color3.fromRGB(118, 90, 157),
					Density = 0.36,
					Glare = 0.08,
					Haze = 2.15,
					Offset = 0.05,
				},
			},
		},
	},

	Horror = {
		lighting = {
			Ambient = Color3.fromRGB(22, 24, 27),
			Brightness = 0.8,
			ClockTime = 1.2,
			EnvironmentDiffuseScale = 0.15,
			EnvironmentSpecularScale = 0.22,
			ExposureCompensation = -0.28,
			FogColor = Color3.fromRGB(24, 28, 30),
			FogEnd = 210,
			FogStart = 12,
			OutdoorAmbient = Color3.fromRGB(34, 31, 35),
			ShadowSoftness = 0.95,
		},
		effects = {
			Color = {
				className = "ColorCorrectionEffect",
				enabled = true,
				properties = {
					Brightness = -0.06,
					Contrast = 0.32,
					Saturation = -0.45,
					TintColor = Color3.fromRGB(200, 224, 207),
				},
			},
			Bloom = {
				className = "BloomEffect",
				enabled = true,
				properties = { Intensity = 0.1, Size = 18, Threshold = 1.8 },
			},
			Atmosphere = {
				className = "Atmosphere",
				enabled = true,
				properties = {
					Color = Color3.fromRGB(54, 60, 57),
					Decay = Color3.fromRGB(16, 19, 18),
					Density = 0.52,
					Glare = 0,
					Haze = 2.8,
					Offset = -0.18,
				},
			},
		},
	},

	NightVision = {
		lighting = {
			Ambient = Color3.fromRGB(42, 84, 44),
			Brightness = 1.4,
			ClockTime = 0,
			EnvironmentDiffuseScale = 0.35,
			EnvironmentSpecularScale = 0.15,
			ExposureCompensation = 0.18,
			FogColor = Color3.fromRGB(15, 42, 17),
			FogEnd = 380,
			FogStart = 28,
			OutdoorAmbient = Color3.fromRGB(55, 112, 58),
			ShadowSoftness = 0.6,
		},
		effects = {
			Color = {
				className = "ColorCorrectionEffect",
				enabled = true,
				properties = {
					Brightness = 0.08,
					Contrast = 0.42,
					Saturation = -0.2,
					TintColor = Color3.fromRGB(132, 255, 134),
				},
			},
			Bloom = {
				className = "BloomEffect",
				enabled = true,
				properties = { Intensity = 0.38, Size = 22, Threshold = 0.72 },
			},
		},
	},

	Noir = {
		lighting = {
			Ambient = Color3.fromRGB(55, 55, 58),
			Brightness = 1.55,
			ClockTime = 20.4,
			EnvironmentDiffuseScale = 0.3,
			EnvironmentSpecularScale = 0.45,
			ExposureCompensation = -0.12,
			FogColor = Color3.fromRGB(70, 70, 76),
			FogEnd = 620,
			FogStart = 50,
			OutdoorAmbient = Color3.fromRGB(72, 72, 78),
			ShadowSoftness = 0.8,
		},
		effects = {
			Color = {
				className = "ColorCorrectionEffect",
				enabled = true,
				properties = {
					Brightness = -0.03,
					Contrast = 0.45,
					Saturation = -1,
					TintColor = Color3.fromRGB(235, 238, 255),
				},
			},
			Bloom = {
				className = "BloomEffect",
				enabled = true,
				properties = { Intensity = 0.2, Size = 34, Threshold = 1.25 },
			},
		},
	},

	WarmSunset = {
		lighting = {
			Ambient = Color3.fromRGB(118, 83, 61),
			Brightness = 2.15,
			ClockTime = 18.1,
			ColorShift_Top = Color3.fromRGB(255, 160, 91),
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.7,
			ExposureCompensation = -0.03,
			FogColor = Color3.fromRGB(255, 177, 122),
			FogEnd = 900,
			FogStart = 80,
			OutdoorAmbient = Color3.fromRGB(153, 106, 79),
			ShadowSoftness = 0.62,
		},
		effects = {
			Color = {
				className = "ColorCorrectionEffect",
				enabled = true,
				properties = {
					Brightness = 0.03,
					Contrast = 0.14,
					Saturation = 0.12,
					TintColor = Color3.fromRGB(255, 219, 188),
				},
			},
			Bloom = {
				className = "BloomEffect",
				enabled = true,
				properties = { Intensity = 0.28, Size = 48, Threshold = 1.05 },
			},
			SunRays = {
				className = "SunRaysEffect",
				enabled = true,
				properties = { Intensity = 0.115, Spread = 0.9 },
			},
		},
	},
}

local function cloneDictionary(source: Dictionary?): Dictionary
	local copy = {}
	if source == nil then
		return copy
	end

	for key, value in source do
		copy[key] = value
	end

	return copy
end

local function cloneSettings(settings: ShaderSettings): ShaderSettings
	local copiedEffects = {}

	if settings.effects ~= nil then
		for effectName, config in settings.effects do
			copiedEffects[effectName] = {
				className = config.className,
				enabled = config.enabled,
				properties = cloneDictionary(config.properties),
			}
		end
	end

	return {
		lighting = cloneDictionary(settings.lighting),
		effects = copiedEffects,
	}
end


local function withDefaultClearUnused(options: ApplyOptions?): ApplyOptions
	local safeOptions = cloneDictionary(options :: any) :: ApplyOptions
	if safeOptions.clearUnusedEffects == nil then
		safeOptions.clearUnusedEffects = true
	end

	return safeOptions
end

local function assertNotDestroyed(self: ShaderCustomizerState)
	assert(not self._destroyed, "Cannot use a destroyed ShaderCustomizer")
end

local function assertEffectClass(className: string)
	assert(EFFECT_CLASSES[className] == true, `Unsupported lighting effect class "{className}"`)
end

local function shouldTween(value: any): boolean
	local valueType = typeof(value)
	return valueType == "number" or valueType == "Color3" or valueType == "Vector3"
end

local function applyProperties(instance: Instance, properties: Dictionary, tweenInfo: TweenInfo?)
	local instantProperties = {}
	local tweenProperties = {}

	for propertyName, propertyValue in properties do
		if tweenInfo ~= nil and shouldTween(propertyValue) then
			tweenProperties[propertyName] = propertyValue
		else
			instantProperties[propertyName] = propertyValue
		end
	end

	for propertyName, propertyValue in instantProperties do
		(instance :: any)[propertyName] = propertyValue
	end

	if next(tweenProperties) ~= nil then
		TweenService:Create(instance, tweenInfo, tweenProperties):Play()
	end
end

local function setEnabled(instance: Instance, enabled: boolean?)
	if enabled == nil then
		return
	end

	if instance:IsA("PostEffect") then
		(instance :: PostEffect).Enabled = enabled
	end
end

local function getClassProperties(className: string): { string }
	return EFFECT_PROPERTIES[className] or {}
end

local function captureLighting(): Dictionary
	local state = {}
	for _, propertyName in LIGHTING_PROPERTIES do
		state[propertyName] = (Lighting :: any)[propertyName]
	end

	return state
end

local function captureEffect(instance: Instance): EffectConfig
	local properties = {}
	for _, propertyName in getClassProperties(instance.ClassName) do
		properties[propertyName] = (instance :: any)[propertyName]
	end

	return {
		className = instance.ClassName,
		enabled = if instance:IsA("PostEffect") then (instance :: PostEffect).Enabled else true,
		properties = properties,
	}
end

function ShaderCustomizer.new(options: ShaderCustomizerOptions?): ShaderCustomizer
	local safeOptions = options or {}
	local self: ShaderCustomizerState = setmetatable({
		_prefix = safeOptions.prefix or DEFAULT_PREFIX,
		_defaultTweenInfo = safeOptions.defaultTweenInfo or DEFAULT_TWEEN_INFO,
		_originalState = { lighting = {}, effects = {} },
		_effects = {},
		_destroyed = false,
		Changed = Signal.new(),
		PresetApplied = Signal.new(),
		EffectChanged = Signal.new(),
		Restored = Signal.new(),
		Destroyed = Signal.new(),
	}, ShaderCustomizer) :: any

	if safeOptions.captureOriginalState ~= false then
		self._originalState = self:CaptureState()
	end

	return self
end

function ShaderCustomizer.GetPreset(presetName: string): ShaderSettings?
	local preset = PRESETS[presetName]
	if preset == nil then
		return nil
	end

	return cloneSettings(preset)
end

function ShaderCustomizer.GetPresets(): { [string]: ShaderSettings }
	local presets = {}
	for presetName, preset in PRESETS do
		presets[presetName] = cloneSettings(preset)
	end

	return presets
end

function ShaderCustomizer.RegisterPreset(presetName: string, settings: ShaderSettings)
	assert(type(presetName) == "string" and presetName ~= "", "ShaderCustomizer.RegisterPreset needs a non-empty preset name")
	PRESETS[presetName] = cloneSettings(settings)
end

function ShaderCustomizer:CaptureState(): ShaderSettings
	local effects = {}

	for _, child in Lighting:GetChildren() do
		if EFFECT_CLASSES[child.ClassName] == true then
			effects[child.Name] = captureEffect(child)
		end
	end

	return {
		lighting = captureLighting(),
		effects = effects,
	}
end

function ShaderCustomizer:GetEffect(effectName: string): Instance?
	local existing = self._effects[effectName]
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end

	local lightingName = self._prefix .. effectName
	local child = Lighting:FindFirstChild(lightingName)
	if child ~= nil then
		self._effects[effectName] = child
		return child
	end

	return nil
end

function ShaderCustomizer:SetLighting(properties: Dictionary, options: ApplyOptions?)
	assertNotDestroyed(self :: any)
	assert(type(properties) == "table", "ShaderCustomizer:SetLighting(properties) needs a table")

	local safeOptions = options or {}
	local tweenInfo = if safeOptions.tween == true then safeOptions.tweenInfo or self._defaultTweenInfo else nil

	applyProperties(Lighting, properties, tweenInfo)
	self.Changed:Fire("Lighting", cloneDictionary(properties))
end

function ShaderCustomizer:SetEffect(
	effectName: string,
	className: string,
	properties: Dictionary?,
	enabled: boolean?,
	options: ApplyOptions?
): Instance
	assertNotDestroyed(self :: any)
	assert(type(effectName) == "string" and effectName ~= "", "ShaderCustomizer:SetEffect needs a non-empty effect name")
	assert(type(className) == "string" and className ~= "", "ShaderCustomizer:SetEffect needs a class name")
	assertEffectClass(className)

	local effect = self:GetEffect(effectName)
	if effect ~= nil and effect.ClassName ~= className then
		effect:Destroy()
		effect = nil
	end

	if effect == nil then
		effect = Instance.new(className)
		effect.Name = self._prefix .. effectName
		effect.Parent = Lighting
		self._effects[effectName] = effect
	end

	setEnabled(effect, enabled)

	if properties ~= nil then
		local safeOptions = options or {}
		local tweenInfo = if safeOptions.tween == true then safeOptions.tweenInfo or self._defaultTweenInfo else nil
		applyProperties(effect, properties, tweenInfo)
	end

	self.EffectChanged:Fire(effectName, effect, cloneDictionary(properties), enabled)
	self.Changed:Fire("Effect", effectName, effect)

	return effect
end

function ShaderCustomizer:Apply(settings: ShaderSettings, options: ApplyOptions?)
	assertNotDestroyed(self :: any)
	assert(type(settings) == "table", "ShaderCustomizer:Apply(settings) needs a settings table")

	local safeOptions = options or {}

	if settings.lighting ~= nil then
		self:SetLighting(settings.lighting, safeOptions)
	end

	local usedEffects = {}
	if settings.effects ~= nil then
		for effectName, config in settings.effects do
			local className = config.className
			assert(type(className) == "string" and className ~= "", `Effect "{effectName}" needs a className`)

			usedEffects[effectName] = true
			self:SetEffect(effectName, className, config.properties, config.enabled, safeOptions)
		end
	end

	if safeOptions.clearUnusedEffects == true then
		for effectName, effect in self._effects do
			if usedEffects[effectName] ~= true then
				effect:Destroy()
				self._effects[effectName] = nil
			end
		end
	end
end

function ShaderCustomizer:ApplyPreset(presetName: string, options: ApplyOptions?)
	assert(type(presetName) == "string" and presetName ~= "", "ShaderCustomizer:ApplyPreset needs a non-empty preset name")

	local preset = PRESETS[presetName]
	assert(preset ~= nil, `Unknown shader preset "{presetName}"`)

	local safeOptions = withDefaultClearUnused(options)
	self:Apply(preset, safeOptions)
	self.PresetApplied:Fire(presetName, cloneSettings(preset))
end

function ShaderCustomizer:Restore(state: ShaderSettings?, options: ApplyOptions?)
	assertNotDestroyed(self :: any)

	local targetState = state or self._originalState
	local safeOptions = withDefaultClearUnused(options)
	self:Apply(targetState, safeOptions)
	self.Restored:Fire(cloneSettings(targetState))
end

function ShaderCustomizer:ClearEffects()
	assertNotDestroyed(self :: any)

	for effectName, effect in self._effects do
		if effect.Parent ~= nil then
			effect:Destroy()
		end

		self._effects[effectName] = nil
	end

	for _, child in Lighting:GetChildren() do
		if string.sub(child.Name, 1, #self._prefix) == self._prefix and EFFECT_CLASSES[child.ClassName] == true then
			child:Destroy()
		end
	end

	self.Changed:Fire("EffectsCleared")
end

function ShaderCustomizer:Destroy()
	if self._destroyed then
		return
	end

	self:ClearEffects()
	self._destroyed = true
	self.Destroyed:Fire()

	self.Changed:Destroy()
	self.PresetApplied:Destroy()
	self.EffectChanged:Destroy()
	self.Restored:Destroy()
	self.Destroyed:Destroy()
	table.clear(self._effects)
end

return ShaderCustomizer
