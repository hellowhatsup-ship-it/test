# Roblox Luau Modules Usage Guide

This repo gives you three ModuleScripts you can place in the same Roblox folder:

- `Signal.lua` for custom listener events.
- `Inserter.lua` for cloning registered templates into the game.
- `ShaderCustomizer.lua` for cool Lighting/post-processing presets.

## 1. Install from GitHub into Roblox Studio

1. Put `Signal.lua`, `Inserter.lua`, and `ShaderCustomizer.lua` in the same folder in Roblox Studio, such as `ReplicatedStorage/Modules` or `ServerScriptService/Modules`.
2. Keep the file names as `Signal`, `Inserter`, and `ShaderCustomizer` when they become ModuleScripts.
3. `Inserter` and `ShaderCustomizer` both use `require(script.Parent.Signal)`, so `Signal` must be a sibling ModuleScript in the same parent folder.

Example folder layout:

```text
ReplicatedStorage
└── Modules
    ├── Signal
    ├── Inserter
    └── ShaderCustomizer
```

Example require setup:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Signal = require(Modules.Signal)
local Inserter = require(Modules.Inserter)
local ShaderCustomizer = require(Modules.ShaderCustomizer)
```

## 2. Use `ShaderCustomizer`

`ShaderCustomizer` edits Roblox `Lighting` and creates managed post-processing effects such as `ColorCorrectionEffect`, `BloomEffect`, `SunRaysEffect`, `DepthOfFieldEffect`, `BlurEffect`, and `Atmosphere`.

### Apply a built-in shader preset

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShaderCustomizer = require(ReplicatedStorage.Modules.ShaderCustomizer)

local shaders = ShaderCustomizer.new()

shaders:ApplyPreset("Cinematic", {
    tween = true,
    tweenInfo = TweenInfo.new(1.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
})
```

Built-in preset names:

- `Clean`
- `Cinematic`
- `Vibrant`
- `Dreamy`
- `Horror`
- `NightVision`
- `Noir`
- `WarmSunset`

### Listen for shader changes

```lua
shaders.PresetApplied:Connect(function(presetName)
    print("Applied shader preset:", presetName)
end)

shaders.EffectChanged:Connect(function(effectName, effect)
    print("Updated effect:", effectName, effect.ClassName)
end)
```

### Create your own custom shader look

```lua
shaders:Apply({
    lighting = {
        ClockTime = 18.2,
        Brightness = 2.4,
        ExposureCompensation = -0.05,
        Ambient = Color3.fromRGB(120, 90, 70),
        OutdoorAmbient = Color3.fromRGB(155, 110, 85),
        FogColor = Color3.fromRGB(255, 185, 135),
        FogStart = 80,
        FogEnd = 900,
    },
    effects = {
        Color = {
            className = "ColorCorrectionEffect",
            enabled = true,
            properties = {
                Brightness = 0.03,
                Contrast = 0.16,
                Saturation = 0.12,
                TintColor = Color3.fromRGB(255, 225, 200),
            },
        },
        Bloom = {
            className = "BloomEffect",
            enabled = true,
            properties = {
                Intensity = 0.25,
                Size = 40,
                Threshold = 1.1,
            },
        },
    },
}, {
    tween = true,
    clearUnusedEffects = true,
})
```

### Save and restore the current Lighting state

```lua
local beforeShader = shaders:CaptureState()

shaders:ApplyPreset("Horror", { tween = true })

task.wait(10)

shaders:Restore(beforeShader, { tween = true })
```

### Register a custom preset

```lua
ShaderCustomizer.RegisterPreset("MyCoolPreset", {
    lighting = {
        ClockTime = 14,
        Brightness = 3,
        ExposureCompensation = 0.1,
    },
    effects = {
        Color = {
            className = "ColorCorrectionEffect",
            enabled = true,
            properties = {
                Contrast = 0.2,
                Saturation = 0.35,
                TintColor = Color3.fromRGB(240, 250, 255),
            },
        },
    },
})

shaders:ApplyPreset("MyCoolPreset", { tween = true })
```

## 3. Use `Inserter`

`Inserter` lets you register templates and clone them into `workspace` or another parent with names, attributes, properties, tags, and placement.

### Register and insert one template

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inserter = require(ReplicatedStorage.Modules.Inserter)

local inserter = Inserter.new()
local templatesFolder = ReplicatedStorage:WaitForChild("Templates")

inserter:Register("Coin", templatesFolder:WaitForChild("Coin"))

local record = inserter:Insert("Coin", {
    parent = workspace,
    name = "SpawnedCoin",
    position = Vector3.new(0, 5, 0),
    attributes = {
        Value = 10,
    },
    tags = { "Pickup" },
})

print("Spawned:", record.id, record.instance)
```

### Listen to insert/remove events

```lua
inserter.Inserted:Connect(function(record, instance)
    print("Inserted", record.key, instance:GetFullName())
end)

inserter.Removed:Connect(function(record)
    print("Removed", record.id)
end)
```

### Remove inserted objects

```lua
record:Destroy()
-- or:
inserter:Remove(record.id)
-- or:
inserter:Clear()
```

## 4. Use `Signal` by itself

`Signal` is useful when you want your own custom events without creating Roblox `BindableEvent` instances.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Modules.Signal)

local RoundStarted = Signal.new()

local connection = RoundStarted:Connect(function(roundNumber)
    print("Round started:", roundNumber)
end)

RoundStarted:Fire(1)
connection:Disconnect()
RoundStarted:Destroy()
```

Use `Once` for a one-time listener:

```lua
RoundStarted:Once(function(roundNumber)
    print("This only runs once for round", roundNumber)
end)
```

Use `Wait` inside a running thread when you want to yield until the next fire:

```lua
task.spawn(function()
    local roundNumber = RoundStarted:Wait()
    print("Wait finished for round", roundNumber)
end)
```

## 5. Quick client-side shader button example

Put this in a `LocalScript` if you want a quick keybind to cycle looks for one player.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ShaderCustomizer = require(ReplicatedStorage.Modules.ShaderCustomizer)

local shaders = ShaderCustomizer.new()
local presets = { "Clean", "Cinematic", "Vibrant", "Dreamy", "Horror", "NightVision", "Noir", "WarmSunset" }
local index = 1

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.G then
        index += 1
        if index > #presets then
            index = 1
        end

        shaders:ApplyPreset(presets[index], { tween = true })
        print("Shader:", presets[index])
    end
end)
```

## 6. Cleanup tips

- Call `Destroy()` on module objects when your system shuts down.
- For `ShaderCustomizer`, `Destroy()` clears managed effects and destroys its signals.
- For `Inserter`, `Destroy()` clears inserted records, destroys inserted instances, and destroys lifecycle signals.
- For `Signal`, `Destroy()` disconnects all listeners and releases waiting threads.
