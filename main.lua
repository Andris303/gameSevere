--!strict
--!optimize 2

if game.GameId == 6170143659 and workspace:FindFirstChild("Ghost") then

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Ghost = workspace.Ghost
local Rooms = workspace.Map.Rooms
local ScriptRestart = false

-- 5, 10, 16

local Colors = {
    Green = Color3.fromRGB(32, 196, 93),
    Red = Color3.fromRGB(196, 45, 32),
    Orange = Color3.fromRGB(234, 165, 16),
    White = Color3.fromRGB(228, 217, 211),
    Blue = Color3.fromRGB(16, 167, 234),
}

local Evidence = {
    EMF = false,
    UV = false,
    SpiritBox = false,
    Orb = false,
    Freeze = false,
    Inscript = false,
    Laser = false,
    Wither = false,
    TypeSiren = false,
}

local SpiritBoxResponses = {
    "CLOSE",
    "FAR",
    "FAR AWAY",
    "AWAY",
    "KILL",
    "HATE",
    "DON'T TURN AROUND",
    "BEHIND",
    "I'M BEHIND YOU",
    "DEATH",
    "ATTACK",
    "HURT",
    "YOUNG",
    "OLD",
    "ELDER"
}

-- Text handler

local TextOffset = 0
local TextYVal = 0
local TextC = 0
local Texts = {}
local TextIds = {}

local test = Drawing.new("Text")
test.Text = "XYZ"
test.Size = 20
test.Font = 0
TextOffset = test.TextBounds.Y
TextYVal = Camera.ViewportSize.Y - 25
test:Remove()

local function AddText(id, text, color)
    if TextIds[id] then return end

    TextC += 1
    TextIds[id] = TextC
    TextYVal -= TextOffset

    Texts[id] = Drawing.new("Text")
    Texts[id].Text = text
    Texts[id].Size = 20
    Texts[id].Font = 0
    Texts[id].Position = Vector2.new(25, TextYVal)
    Texts[id].Color = color
    Texts[id].Visible = true
end

local function RemoveText(id)
    if not TextIds[id] then return end

    local Stack = TextIds[id]
    local temp = TextYVal

    for i, inst in pairs(TextIds) do
        if not inst then continue end
        if inst <= Stack then continue end
        TextIds[i] = inst - 1
        temp += TextOffset
        Texts[i].Position = Vector2.new(25, temp)
    end

    TextYVal += TextOffset
    TextC -= 1
    TextIds[id] = nil
    Texts[id]:Remove()
end

local BodyParts = {
    "Head",
    "Torso",
    "Right Arm",
    "Left Arm",
    "Right Leg",
    "Left Leg"
}

local Convex = {
    Scratch = {
        Points = {},
        Hull = {},
        Poly = {}
    },

    Static = {
        HWMPoints = 0,
        HWMHull = 0,
        HWMPoly = 0
    }
}

-- Highlighter

local function TruncateBuffer(Buffer, NewSize, HighWaterMark)
    for Index = NewSize + 1, HighWaterMark do
        Buffer[Index] = nil
    end
    return math.max(NewSize, HighWaterMark)
end

local function CrossDimension(OriginX, OriginY, PointAX, PointAY, PointBX, PointBY)
    return (PointAX - OriginX) * (PointBY - OriginY) - (PointAY - OriginY) * (PointBX - OriginX)
end

local function CalculateConvexHull(Points, PointCount, Outer)
    if PointCount == 0 then return 0 end
    if PointCount == 1 then Outer[1] = Points[1]; return 1 end
    if PointCount == 2 then Outer[1] = Points[1]; Outer[2] = Points[2]; return 2 end
    table.sort(Points, function(PointA, PointB)
        return PointA.X < PointB.X or (PointA.X == PointB.X and PointA.Y < PointB.Y)
    end)
    local Size = 0
    for Index = 1, PointCount do
        local Point = Points[Index]
        while Size >= 2 and CrossDimension(Outer[Size - 1].X, Outer[Size - 1].Y, Outer[Size].X, Outer[Size].Y, Point.X, Point.Y) <= 0 do
            Size = Size - 1
        end
        Size = Size + 1
        Outer[Size] = Point
    end
    local LowerHullSize = Size
    for Index = PointCount - 1, 1, -1 do
        local Point = Points[Index]
        while Size > LowerHullSize and CrossDimension(Outer[Size - 1].X, Outer[Size - 1].Y, Outer[Size].X, Outer[Size].Y, Point.X, Point.Y) <= 0 do
            Size = Size - 1
        end
        Size = Size + 1
        Outer[Size] = Point
    end
    return Size - 1
end

local function ProjectPartCorners(Part, WriteOffset)
    local PositionX = Part.Position.X
    local PositionY = Part.Position.Y
    local PositionZ = Part.Position.Z
    local HalfSizeX = Part.Size.X * 0.5
    local HalfSizeY = Part.Size.Y * 0.5
    local HalfSizeZ = Part.Size.Z * 0.5
    local RightVector = Part.RightVector
    local UpVector = Part.UpVector
    local LookVector = Part.LookVector
    local RightX = RightVector.X * HalfSizeX
    local RightY = RightVector.Y * HalfSizeX
    local RightZ = RightVector.Z * HalfSizeX
    local UpX = UpVector.X * HalfSizeY
    local UpY = UpVector.Y * HalfSizeY
    local UpZ = UpVector.Z * HalfSizeY
    local LookX = LookVector.X * HalfSizeZ
    local LookY = LookVector.Y * HalfSizeZ
    local LookZ = LookVector.Z * HalfSizeZ
    local SignR = 1
    for _ = 1, 2 do
        local SignU = 1
        for _ = 1, 2 do
            local SignL = 1
            for _ = 1, 2 do
                local WorldPoint = Vector3.new(
                    PositionX + SignR * RightX + SignU * UpX + SignL * LookX,
                    PositionY + SignR * RightY + SignU * UpY + SignL * LookY,
                    PositionZ + SignR * RightZ + SignU * UpZ + SignL * LookZ
                )
                local ScreenPoint, OnScreen = Camera:WorldToScreenPoint(WorldPoint)
                if OnScreen then
                    WriteOffset = WriteOffset + 1
                    local Slot = Convex.Scratch.Points[WriteOffset]
                    if Slot then
                        Slot.X = ScreenPoint.X
                        Slot.Y = ScreenPoint.Y
                    else
                        Convex.Scratch.Points[WriteOffset] = {X = ScreenPoint.X, Y = ScreenPoint.Y}
                    end
                end
                SignL = -1
            end
            SignU = -1
        end
        SignR = -1
    end
    return WriteOffset
end

local function DrawPolygon(Hull, Size, Color, Opacity)
    if Size < 3 then return end
    local Pivot = Vector2.new(Hull[1].X, Hull[1].Y)
    for Index = 2, Size - 1 do
        DrawingImmediate.FilledTriangle(Pivot, Vector2.new(Hull[Index].X, Hull[Index].Y), Vector2.new(Hull[Index + 1].X, Hull[Index + 1].Y), Color, Opacity)
    end
end

local function DrawOutline(Hull, Size, Color, Opacity, Thickness)
    if Size < 2 then return end
    for Index = 1, Size do
        local Entry = Hull[Index]
        Convex.Scratch.Poly[Index] = Vector2.new(Entry.X, Entry.Y)
    end
    Convex.Scratch.Poly[Size + 1] = Vector2.new(Hull[1].X, Hull[1].Y)
    Convex.Scratch.Poly[Size + 2] = nil
    if Size + 1 < Convex.Static.HWMPoly then
        for Index = Size + 2, Convex.Static.HWMPoly do
            Convex.Scratch.Poly[Index] = nil
        end
    end
    Convex.Static.HWMPoly = math.max(Convex.Static.HWMPoly, Size + 1)
    DrawingImmediate.Polyline(Convex.Scratch.Poly, Color, 0.5, 2)
end

local function Highlight(inst, color)
    local PointCount = 0
    PointCount = ProjectPartCorners(inst, PointCount)
    Convex.Static.HWMPoints = TruncateBuffer(Convex.Scratch.Points, PointCount, Convex.Static.HWMPoints)
    local Size = CalculateConvexHull(Convex.Scratch.Points, PointCount, Convex.Scratch.Hull)
    Convex.Static.HWMHull = TruncateBuffer(Convex.Scratch.Hull, Size, Convex.Static.HWMHull)
    DrawPolygon(Convex.Scratch.Hull, Size, color, 0.2)
    DrawOutline(Convex.Scratch.Hull, Size, color, 0.7, 0.7)
end

local function Render()
    if _G.Ghost_ESP then
        for i, inst in pairs(BodyParts) do
            if Ghost:FindFirstChild(inst) then
                Highlight(Ghost[inst], _G.Ghost_ESP_Color)
            end
        end
    end

    if _G.UV_ESP then
        for i, inst in pairs(workspace.Handprints:GetChildren()) do
            Highlight(inst, _G.UV_ESP_Color)
        end
    end
end

local SpeedBool = true
local TextLabelBool = true
local GhostSpeedColorBool = true
local DefaultSpeed = tonumber(workspace:GetAttribute("DefaultWalkSpeed"))
local MaxStamina = workspace:GetAttribute("MaxStamina")
local LocalSpeed
local GhostSpeed
if tostring(_G.WalkspeedOffset) == "0" then
    SpeedBool = false
    LocalSpeed = -1
    GhostSpeed = -1
else
    LocalSpeed = memory.readf32(LocalPlayer.Character.Humanoid, tonumber(_G.WalkspeedOffset, 16))
    GhostSpeed = memory.readf32(Ghost.Humanoid, tonumber(_G.WalkspeedOffset, 16))
end

local GhostSpeedText = "Ghost\'s speed: " .. tostring(GhostSpeed)
local SirenSpeedDebuffs = {
    math.floor((DefaultSpeed * 0.8) * 100) / 100,
    math.floor((DefaultSpeed * 1.28) * 100) / 100,
    math.floor((DefaultSpeed * 0.4) * 100) / 100
}

if GhostSpeed < 0 or GhostSpeed > 50 then
    SpeedBool = false
    TextLabelBool = false
    print("Memory offsets outdated! Speed tracker and spirit box tracker is disabled.")
elseif GhostSpeed ~= 11 then
    GhostSpeedColorBool = false
end

if SpeedBool then
    local GhostSpeedColor = Colors.White
    AddText("GhostSpeed", GhostSpeedText, GhostSpeedColor)
end

if tostring(_G.TextLabelOffset) == "0" then
    TextLabelBool = false
end

local Energy = tonumber(LocalPlayer:GetAttribute("Energy"))
local EnergyText = "Your energy: " .. tostring(Energy)
local EnergyColor = Colors.White

if Energy == 0 then
    EnergyColor = Colors.Red
elseif Energy < 20 then
    EnergyColor = Colors.Orange
end

AddText("Energy", EnergyText, EnergyColor)

local FavRoomRaw = Ghost:GetAttribute("FavoriteRoom")
local FavRoom = "Ghost's favorite room: " .. FavRoomRaw
local FavRoomInst = Rooms:FindFirstChild(FavRoomRaw)

AddText("FavRoom", FavRoom, Colors.Blue)

local GhostHunting = false

if Ghost:GetAttribute("Hunting") == "true" then
    GhostHunting = true
    AddText("Hunt", "Ghost is currently hunting", Colors.Red)
else
    AddText("Hunt", "Ghost is not hunting", Colors.Blue)
end

if Ghost:GetAttribute("Gender") == "Male" then
    AddText("Gender", "Keres and Siren can be ruled out", Colors.White)
end

if workspace:FindFirstChild("GhostOrb") then
    Evidence.Orb = true
    send_notification("Ghost Orb evidence found", "warning")
    AddText("OrbEvidence", "Ghost orb evidence found", Colors.Green)
else
    AddText("OrbEvidence", "No ghost orb evidence, can be ruled out", Colors.White)
end

local function Main()
    if not Ghost:FindFirstChild("Humanoid") then return end
    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("Humanoid") then return end
    if not LocalPlayer:FindFirstChild("PlayerGui") then return end
    if not LocalPlayer.PlayerGui:FindFirstChild("Subtitles") then return end
    if not LocalPlayer.PlayerGui.Subtitles:FindFirstChild("Holder") then return end
    if not LocalPlayer.PlayerGui.Subtitles.Holder:FindFirstChild("TextLabel") then return end

    local EnergyAttribute = tonumber(LocalPlayer:GetAttribute("Energy"))
    local FavRoomAttribute = Ghost:GetAttribute("FavoriteRoom")
    local HuntingAttribute = Ghost:GetAttribute("Hunting") == "true"
    local LaserAttribute = Ghost:GetAttribute("LaserVisible") == "true"
    local Temperature = tonumber(FavRoomInst:GetAttribute("Temperature"))
    local HandprintInst = workspace.Handprints:FindFirstChildOfClass("Part")
    local InscriptInst = workspace.ScratchText:FindFirstChildOfClass("Model")
    local Subtitle = LocalPlayer.PlayerGui.Subtitles.Holder.TextLabel

    if SpeedBool then
        local NewGhostSpeed = memory.readf32(Ghost.Humanoid, tonumber(_G.WalkspeedOffset, 16))
        if GhostSpeed ~= NewGhostSpeed then
            GhostSpeed = NewGhostSpeed
            if GhostSpeed == 11 and GhostSpeedColorBool then
                Texts["GhostSpeed"].Color = Colors.White
            elseif GhostSpeedColorBool then
                Texts["GhostSpeed"].Color = Colors.Orange
            end
            GhostSpeedText = "Ghost\'s speed: " .. tostring(GhostSpeed)
            Texts["GhostSpeed"].Text = GhostSpeedText
        end
        LocalSpeed = memory.readf32(LocalPlayer.Character.Humanoid, tonumber(_G.WalkspeedOffset, 16))
    end

    if TextLabelBool then
        local SubtitleText = memory.readstring(Subtitle, tonumber(_G.TextLabelTextOffset, 16))
        if SubtitleText == "- HUMMING -" and not Evidence.TypeSiren then
            if not Evidence.SpiritBox then
                Evidence.SpiritBox = true
                send_notification("Spirit box evidence found", "warning")
                AddText("SpiritBoxEvidence", "Spirit box evidence found", Colors.Green)
            end
            
            Evidence.TypeSiren = true
            send_notification("Ghost type found: Siren", "warning")
            AddText("SirenType", "Ghost type found: Siren", Colors.Red)
        end

        for i, inst in pairs(SpiritBoxResponses) do
            if SubtitleText == inst and not Evidence.SpiritBox then
                Evidence.SpiritBox = true
                send_notification("Spirit box evidence found", "warning")
                AddText("SpiritBoxEvidence", "Spirit box evidence found", Colors.Green)
            end
        end
    end

    if EnergyAttribute ~= Energy then
        Energy = EnergyAttribute
        EnergyText = "Your energy: " .. tostring(Energy)
        Texts["Energy"].Text = EnergyText
        if Energy == 0 then
            Texts["Energy"].Color = Colors.Red
        elseif Energy < 20 then
            if Texts["Energy"].Color ~= Colors.Orange then
                Texts["Energy"].Color = Colors.Orange
            end
        end
    end

    if _G.Inf_Stamina then
        LocalPlayer:SetAttribute("Stamina", MaxStamina)
    end

    if FavRoomAttribute ~= FavRoomRaw then
        send_notification("Ghost\'s favorite room changed", "warning")
        FavRoomRaw = FavRoomAttribute
        FavRoom = "Ghost's favorite room: " .. FavRoomRaw
        FavRoomInst = Rooms:FindFirstChild(FavRoomRaw)
        Texts["FavRoom"].Text = FavRoom
    end

    if HuntingAttribute and not GhostHunting then
        GhostHunting = true
        send_notification("Ghost started hunting", "error")
        Texts["Hunt"].Text = "Ghost is currently hunting"
        Texts["Hunt"].Color = Colors.Red
    elseif not HuntingAttribute and GhostHunting then
        GhostHunting = false
        send_notification("Ghost stopped hunting", "info")
        Texts["Hunt"].Text = "Ghost is not hunting"
        Texts["Hunt"].Color = Colors.Blue
    end

    if HandprintInst and not Evidence.UV then
        Evidence.UV = true
        send_notification("UV handprints evidence found", "warning")
        AddText("UVEvidence", "UV handprints evidence found", Colors.Green)
    end

    if InscriptInst and not Evidence.Inscript then
        Evidence.Inscript = true
        send_notification("Inscription evidence found", "warning")
        AddText("WriteEvidence", "Inscription evidence found", Colors.Green)
    end

    if LaserAttribute and not Evidence.Laser then
        Evidence.Laser = true
        send_notification("Laser projector evidence found", "warning")
        AddText("LaserEvidence", "Laser projector evidence found", Colors.Green)
    end

    if Temperature < 0 and not Evidence.Freeze then
        Evidence.Freeze = true
        send_notification("Freezing temperature evidence found", "warning")
        AddText("FreezeEvidence", "Freezing temperature evidence found", Colors.Green)
    end

    for i, inst in pairs(workspace.Items:GetChildren()) do
        local ItemName = inst:GetAttribute("ItemName")
        local RewardBool = inst:GetAttribute("PhotoRewardAvailable") == "true"
        local ReadingLevel = inst:GetAttribute("ReadingLevel") or 1
        local RewardType = inst:GetAttribute("PhotoRewardType") or "Nil"

        if ItemName == "Spirit Book" and RewardBool and RewardType == "Inscription" and not Evidence.Inscript then
            Evidence.Inscript = true
            send_notification("Inscription evidence found", "warning")
            AddText("InscriptEvidence", "Inscription evidence found", Colors.Green)
        end

        if ItemName == "Flower Pot" and RewardBool and RewardType == "WitheredFlowers" and not Evidence.Wither then
            Evidence.Wither = true
            send_notification("Wither evidence found", "warning")
            AddText("WitherEvidence", "Wither evidence found", Colors.Green)
        end

        if ItemName == "EMF Reader" and tonumber(ReadingLevel) > 4.5 and not Evidence.EMF then
            Evidence.EMF = true
            send_notification("EMF level 5 evidence found", "warning")
            AddText("EMFEvidence", "EMF level 5 evidence found", Colors.Green)
        end
    end

    for i, inst in pairs(Players:GetChildren()) do
        if not inst.Character then continue end
        local Humanoid = inst.Character:FindFirstChild("Humanoid")
        if not Humanoid then continue end

        if SpeedBool and not Evidence.TypeSiren then
            for j, val in pairs(SirenSpeedDebuffs) do
                if LocalSpeed == val then
                    Evidence.TypeSiren = true
                    send_notification("Ghost type found: Siren", "warning")
                    AddText("SirenType", "Ghost type found: Siren", Colors.Red)
                end
            end
        end

        for j, part in pairs(inst.Character:GetChildren()) do
            if part:GetAttribute("ItemName") == "EMF Reader" then
                if not part:GetAttribute("ReadingLevel") then continue end
                if tonumber(part:GetAttribute("ReadingLevel")) > 4.5 and not Evidence.EMF then
                    Evidence.EMF = true
                    send_notification("EMF level 5 evidence found", "warning")
                    AddText("EMFEvidence", "EMF level 5 evidence found", Colors.Green)
                end
            end
        end
    end
end

-- Initialization

print("Script Started")

RunService.Render:Connect(Render)
RunService.PostLocal:Connect(Main)

else
    print("Wrong game")
end
