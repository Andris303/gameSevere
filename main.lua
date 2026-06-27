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
local SkinwalkerPartiallyFound = false
local TestMode = false -- do not enable, might cause bugs

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
    TypeFound = false,
    TypeSiren = false,
    TypeBanshee = false
}

local GhostCodes = {
    EMFInscriptWither = "Aswang",
    UVOrbFreeze = "Banshee",
    EMFUVFreeze = "Demon",
    FreezeLaserWither = "Dullahan",
    UVFreezeWither = "Dybbuk",
    UVSpiritBoxLaser = "Entity",
    SpiritBoxOrbFreeze = "Ghoul",
    UVSpiritBoxWither = "Keres",
    UVOrbInscript = "Leviathan",
    EMFSpiritBoxOrb = "Nightmare",
    SpiritBoxFreezeLaser = "Oni",
    EMFUVOrb = "Phantom",
    EMFSpiritBoxInscript = "Ravager",
    EMFFreezeInscript = "Revenant",
    EMFInscriptLaser = "Shadow",
    EMFSpiritBoxWither = "Siren",
    SpiritBoxFreezeInscript = "Skinwalker",
    EMFFreezeLaser = "Specter",
    UVSpiritBoxInscript = "Spirit",
    UVOrbLaser = "Umbra",
    UVInscriptWither = "Vesper",
    OrbFreezeWither = "Vex",
    OrbInscriptLaser = "Wendigo",
    OrbLaserWither = "The Wisp",
    EMFSpiritBoxLaser = "Wraith"
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
local DefaultSpeed = tonumber(workspace:GetAttribute("DefaultWalkSpeed"))
local MaxStamina = workspace:GetAttribute("MaxStamina")
local CustomDif = workspace:GetAttribute("Difficulty") == "Custom"
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

local GhostSpeedText = "Ghost\'s speed: " .. tostring(math.floor(GhostSpeed * 100) / 100)
local SirenSpeedDebuffs = {
    math.floor((DefaultSpeed * 0.8) * 100) / 100,
    math.floor((DefaultSpeed * 1.28) * 100) / 100,
    math.floor((DefaultSpeed * 0.4) * 100) / 100
}

if GhostSpeed < 0 or GhostSpeed > 50 then
    SpeedBool = false
    print("Memory offsets outdated! Speed tracker and spirit box tracker is disabled.")
end

if SpeedBool then
    local GhostSpeedColor = Colors.White
    if not CustomDif or TestMode then
        if math.floor(GhostSpeed * 100) / 100 ~= 11 then
            GhostSpeedColor = Colors.Orange
        end
    end
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

local function ShowType(ghost)
    if Evidence.TypeFound then return end
    if SkinwalkerPartiallyFound then RemoveText("GhostFoundPartial") end
    Evidence.TypeFound = true
    local OutputText = "Ghost type found: " .. ghost
    send_notification(OutputText, "warning")
    AddText("GhostFound", OutputText, Colors.Red)
end

local function ShowEvidence(textshort, text)
    if Evidence[textshort] then return end
    Evidence[textshort] = true
    local OutputText = text .. " evidence found"
    send_notification(OutputText, "warning")
    AddText(textshort, OutputText, Colors.Green)
end

if Ghost:GetAttribute("Headless") then
    ShowType("Dullahan")
end

if not Ghost:FindFirstChild("GhostFootsteps") then
    ShowType("Umbra")
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
    local EMFAttribute = Ghost:GetAttribute("LastEMFLevel5Time")
    local HandprintInst = workspace.Handprints:FindFirstChildOfClass("Part")
    local InscriptInst = workspace.ScratchText:FindFirstChildOfClass("Model")
    local Subtitle = LocalPlayer.PlayerGui.Subtitles.Holder.TextLabel

    if SpeedBool then
        local NewGhostSpeed = memory.readf32(Ghost.Humanoid, tonumber(_G.WalkspeedOffset, 16))
        if GhostSpeed ~= NewGhostSpeed then
            GhostSpeed = NewGhostSpeed
            local TruncatedSpeed = math.floor(GhostSpeed * 100) / 100
            if not CustomDif or TestMode then
                if GhostSpeed == 11 then
                    Texts["GhostSpeed"].Color = Colors.White
                else
                    Texts["GhostSpeed"].Color = Colors.Orange
                end
                if TruncatedSpeed == 8.25 then
                    ShowType("Aswang")
                elseif TruncatedSpeed == 8.8 then
                    ShowType("Umbra")
                elseif TruncatedSpeed == 13.5 and not Evidence.TypeFound then
                    if Evidence.Orb then
                        ShowType("Phantom")
                    else
                        ShowType("Oni")
                    end
                elseif TruncatedSpeed ~= 3 and TruncatedSpeed ~= 8.25 and TruncatedSpeed ~= 8.8 and TruncatedSpeed ~= 11 and TruncatedSpeed ~= 13.5 then
                    ShowType("Wendigo")
                end
            end
            GhostSpeedText = "Ghost\'s speed: " .. tostring(TruncatedSpeed)
            Texts["GhostSpeed"].Text = GhostSpeedText
        end
        LocalSpeed = math.floor(memory.readf32(LocalPlayer.Character.Humanoid, tonumber(_G.WalkspeedOffset, 16)) * 100) / 100
    end

    if TextLabelBool then
        local SubtitleText = memory.readstring(Subtitle, tonumber(_G.TextLabelTextOffset, 16))

        for i, inst in pairs(SpiritBoxResponses) do
            if SubtitleText == inst then
                ShowEvidence("SpiritBox", "Spirit Box")
            end
        end

        if SubtitleText == "- HUMMING -" then
            ShowType("Siren")
        end

        if SubtitleText == "> Ghost Wail <" and GhostHunting then
            ShowType("Banshee")
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
        else
            if Texts["Energy"].Color ~= Colors.White then
                Texts["Energy"].Color = Colors.White
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
        Texts["Hunt"].Text = "Ghost is currently hunting"
        Texts["Hunt"].Color = Colors.Red
    elseif not HuntingAttribute and GhostHunting then
        GhostHunting = false
        Texts["Hunt"].Text = "Ghost is not hunting"
        Texts["Hunt"].Color = Colors.Blue
    end

    if HandprintInst then ShowEvidence("UV", "UV handprints") end
    if InscriptInst then ShowEvidence("Inscript", "Inscription") end
    if LaserAttribute then ShowEvidence("Laser", "Laser projector") end
    if EMFAttribute then ShowEvidence("EMF", "EMF level 5") end

    for i, inst in pairs(Rooms:GetChildren()) do
        local RoomTemp = tonumber(inst:GetAttribute("Temperature"))
        if RoomTemp < 0 then ShowEvidence("Freeze", "Freezing temperatures") end
    end

    for i, inst in pairs(workspace.Items:GetChildren()) do
        local ItemName = inst:GetAttribute("ItemName")
        local RewardBool = inst:GetAttribute("PhotoRewardAvailable") == "true"
        local ReadingLevel = inst:GetAttribute("ReadingLevel") or 1
        local RewardType = inst:GetAttribute("PhotoRewardType") or "Nil"

        if ItemName == "Spirit Book" and RewardBool and RewardType == "Inscription" then
            ShowEvidence("Inscript", "Inscription")
        end

        if ItemName == "Flower Pot" and RewardBool and RewardType == "WitheredFlowers" then
            ShowEvidence("Wither", "Wither")
        end
    end

    for i, inst in pairs(Players:GetChildren()) do
        if not inst.Character then continue end
        local Humanoid = inst.Character:FindFirstChild("Humanoid")
        if not Humanoid then continue end

        if SpeedBool and not Evidence.TypeFound then
            for j, val in pairs(SirenSpeedDebuffs) do
                if LocalSpeed == val then
                    ShowType("Siren")
                end
            end
        end
    end

    if Evidence.TypeFound then return end

    local c = 0
    local code = ""

    local function AddCode(string)
        c += 1
        code = code .. string
    end

    if Evidence.EMF then AddCode("EMF") end
    if Evidence.UV then AddCode("UV") end
    if Evidence.SpiritBox then AddCode("SpiritBox") end
    if Evidence.Orb then AddCode("Orb") end
    if Evidence.Freeze then AddCode("Freeze") end
    if Evidence.Inscript then AddCode("Inscript") end
    if Evidence.Laser then AddCode("Laser") end
    if Evidence.Wither then AddCode("Wither") end

    if c == 3 then
        if not SkinwalkerPartiallyFound then
            if code == "OrbFreezeInscript" or code == "SpiritBoxOrbInscript" then
                ShowType("Skinwalker")
            elseif code == "SpiritBoxOrbFreeze" then
                SkinwalkerPartiallyFound = true
                send_notification("Ghost type found: Ghoul", "warning")
                AddText("GhostFoundPartial", "Ghost type found: Ghoul, WARNING: Possibly Skinwalker, try ruling out inscription", Colors.Red)
            end

            if GhostCodes[code] then
                ShowType(GhostCodes[code])
            end
        end
    elseif c == 4 then
        ShowType("Skinwalker")
    end
end

-- Initialization

print("Script Started")

RunService.Render:Connect(Render)
RunService.PostLocal:Connect(Main)

else
    print("Wrong game")
end
