--!strict
--!optimize 2

if game.GameId ~= 6170143659 then
    print("wrong game")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local UVEvidence = false
local WriteEvidence = false
local FreezeEvidence = false
local LaserEvidence = false
local Hunting = false

local Offset = 0
local YVal = 0
local TextC = 0
local Texts = {}
local TextIds = {}

local test = Drawing.new("Text")
test.Text = "XYZ"
test.Size = 20
test.Font = 0
Offset = test.TextBounds.Y
YVal = Camera.ViewportSize.Y - 25
test:Remove()

local function AddText(id, text, color)
    if TextIds[id] then
        print("Attempted to add text with a conflicting ID")
        return
    end

    TextC += 1
    TextIds[id] = TextC
    YVal = YVal - Offset

    Texts[id] = Drawing.new("Text")
    Texts[id].Text = text
    Texts[id].Size = 20
    Texts[id].Font = 0
    Texts[id].Position = Vector2.new(25, YVal)
    Texts[id].Color = color
    Texts[id].Visible = true
end

local function RemoveText(id)
    if not TextIds[id] then
        print("Attempted to remove unregistered text")
        return
    end

    local Stack = TextIds[id]
    local temp = YVal

    for i, inst in pairs(TextIds) do
        if not inst then continue end
        if inst <= Stack then continue end
        TextIds[i] = inst - 1
        temp += Offset
        Texts[i].Position = Vector2.new(25, temp)
    end

    YVal += Offset
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
    DrawPolygon(Convex.Scratch.Hull, Size, color, 0.1)
    DrawOutline(Convex.Scratch.Hull, Size, color, 0.4, 0.4)
end

local function Render()
    for i, inst in pairs(BodyParts) do
        if workspace.Ghost:FindFirstChild(inst) then
            Highlight(workspace.Ghost[inst], Color3.fromRGB(196, 45, 32))
        end
    end
end

local FavRoomRaw = workspace.Ghost:GetAttribute("FavoriteRoom")
local FavRoom = "Ghost's favorite room: " .. FavRoomRaw
AddText("FavRoom", FavRoom, Color3.fromRGB(16, 167, 234))
local FavRoomInst = workspace.Map.Rooms:FindFirstChild(FavRoomRaw)

if workspace.Ghost:GetAttribute("Hunting") == "true" then
    Hunting = true
    AddText("Hunt", "Ghost is currently hunting", Color3.fromRGB(196, 45, 32))
else
    Hunting = false
    AddText("Hunt", "Ghost is not hunting", Color3.fromRGB(16, 167, 234))
end

if workspace:FindFirstChild("GhostOrb") then
    send_notification("Ghost Orb evidence found", "warning")
    AddText("OrbEvidence", "Ghost orb evidence found", Color3.fromRGB(32, 196, 93))
else
    AddText("OrbEvidence", "No ghost orb evidence, can be ruled out", Color3.fromRGB(228, 217, 211))
end

RunService.Render:Connect(Render)

RunService.PostLocal:Connect(function()
    if workspace.Ghost:GetAttribute("FavoriteRoom") ~= FavRoomRaw then
        send_notification("Ghost\'s favorite room changed", "warning")
        FavRoomRaw = workspace.Ghost:GetAttribute("FavoriteRoom")
        FavRoom = "Ghost's favorite room: " .. FavRoomRaw
        FavRoomInst = workspace.Map.Rooms:FindFirstChild(FavRoomRaw)
        Texts["FavRoom"].Text = FavRoom
    end

    if workspace.Ghost:GetAttribute("Hunting") == "true" and not Hunting then
        Hunting = true
        send_notification("Ghost started hunting", "error")
        Texts["Hunt"].Text = "Ghost is currently hunting"
        Texts["Hunt"].Color = Color3.fromRGB(196, 45, 32)
    elseif workspace.Ghost:GetAttribute("Hunting") == "false" and Hunting then
        Hunting = false
        send_notification("Ghost stopped hunting", "info")
        Texts["Hunt"].Text = "Ghost is not hunting"
        Texts["Hunt"].Color = Color3.fromRGB(16, 167, 234)
    end

    if workspace.Handprints:FindFirstChildOfClass("Part") and not UVEvidence then
        UVEvidence = true
        send_notification("UV Handprints evidence found", "warning")
        AddText("UVEvidence", "UV Handprints evidence found", Color3.fromRGB(32, 196, 93))
    end

    if workspace.ScratchText:FindFirstChildOfClass("Model") and not WriteEvidence then
        WriteEvidence = true
        send_notification("Inscription evidence found", "warning")
        AddText("WriteEvidence", "Inscription evidence found", Color3.fromRGB(32, 196, 93))
    end

    if workspace.Ghost:GetAttribute("LaserVisible") == "true" and not LaserEvidence then
        LaserEvidence = true
        send_notification("Laser projector evidence found", "warning")
        AddText("LaserEvidence", "Laser projector evidence found", Color3.fromRGB(32, 196, 93))
    end

    if tonumber(FavRoomInst:GetAttribute("Temperature")) < 0 then
        if not FreezeEvidence then
            FreezeEvidence = true
            send_notification("Freezing temperature evidence found", "warning")
            AddText("FreezeEvidence", "Freezing temperature evidence found", Color3.fromRGB(32, 196, 93))
        end
    end
end)

print("Script Started")
