--!nonstrict
-- MacBook Fan & Thermal Background Service
-- Reads sysfs hardware sensors (applesmc & coretemp) and publishes live state to 'macbook_fan.snapshot'.

local SNAPSHOT = "macbook_fan.snapshot"
local COMMAND = "macbook_fan.command"
local SEP = "__MBP_SEP__"

local snapshot = {
  rpm = 0,
  min_rpm = 1200,
  max_rpm = 6500,
  percent = 0,
  temp = 0,
  daemon_active = false,
  driver_available = false,
  display_mode = "rpm", -- "rpm" | "percent" | "both"
}

local reading = false

local function shellCmd()
  return "cat /sys/devices/platform/applesmc.*/fan1_input 2>/dev/null; echo " .. SEP
    .. "; cat /sys/devices/platform/applesmc.*/fan1_min 2>/dev/null; echo " .. SEP
    .. "; cat /sys/devices/platform/applesmc.*/fan1_max 2>/dev/null; echo " .. SEP
    .. "; (cat /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null); echo " .. SEP
    .. "; systemctl is-active mbpfan 2>/dev/null"
end

local function publish()
  noctalia.state.set(SNAPSHOT, {
    rpm = snapshot.rpm,
    min_rpm = snapshot.min_rpm,
    max_rpm = snapshot.max_rpm,
    percent = snapshot.percent,
    temp = snapshot.temp,
    daemon_active = snapshot.daemon_active,
    driver_available = snapshot.driver_available,
    display_mode = snapshot.display_mode,
  })
end

local function parseOutput(stdout)
  if not stdout or stdout == "" then
    snapshot.driver_available = false
    return
  end

  local parts = {}
  local startIdx = 1
  while true do
    local findStart, findEnd = stdout:find(SEP, startIdx, true)
    if not findStart then
      table.insert(parts, stdout:sub(startIdx))
      break
    end
    table.insert(parts, stdout:sub(startIdx, findStart - 1))
    startIdx = findEnd + 1
  end

  -- Part 1: Current RPM
  local rawRpm = parts[1] and noctalia.string.trim(parts[1]) or ""
  local parsedRpm = tonumber(rawRpm)
  if parsedRpm and parsedRpm >= 0 then
    snapshot.rpm = parsedRpm
    snapshot.driver_available = true
  else
    snapshot.driver_available = false
  end

  -- Part 2: Min RPM
  local rawMin = parts[2] and noctalia.string.trim(parts[2]) or ""
  local parsedMin = tonumber(rawMin)
  if parsedMin and parsedMin > 0 then
    snapshot.min_rpm = parsedMin
  end

  -- Part 3: Max RPM
  local rawMax = parts[3] and noctalia.string.trim(parts[3]) or ""
  local parsedMax = tonumber(rawMax)
  if parsedMax and parsedMax > 0 then
    snapshot.max_rpm = parsedMax
  end

  -- Calculate percentage
  if snapshot.max_rpm > 0 then
    local span = math.max(1, snapshot.max_rpm - snapshot.min_rpm)
    local pct = math.floor(((snapshot.rpm - snapshot.min_rpm) / span) * 100)
    snapshot.percent = math.clamp(pct, 0, 100)
  end

  -- Part 4: CPU Temperature (milli-degrees C)
  local rawTemp = parts[4] and noctalia.string.trim(parts[4]) or ""
  local parsedTemp = tonumber(rawTemp)
  if parsedTemp and parsedTemp > 0 then
    snapshot.temp = math.floor((parsedTemp / 1000) * 10) / 10
  else
    local stats = noctalia.systemStats()
    if stats and stats.cpu and stats.cpu.tempC then
      snapshot.temp = stats.cpu.tempC
    end
  end

  -- Part 5: Daemon status
  local rawDaemon = parts[5] and noctalia.string.trim(parts[5]) or ""
  snapshot.daemon_active = (rawDaemon == "active")
end

local function readHardware()
  if reading then
    return
  end
  reading = true

  noctalia.runAsync(shellCmd(), function(res)
    reading = false
    if res.exitCode == 0 or (res.stdout and res.stdout ~= "") then
      parseOutput(res.stdout or "")
    else
      snapshot.driver_available = false
    end
    publish()
  end, 3000)
end

-- Watch commands dispatched by widget or panel
noctalia.state.watch(COMMAND, function(cmd)
  if type(cmd) ~= "table" then
    return
  end

  if cmd.action == "set_display_mode" and cmd.mode then
    snapshot.display_mode = cmd.mode
    publish()
  elseif cmd.action == "run_setup" then
    local script = (noctalia.pluginDir() or "") .. "/scripts/setup-requirements.sh"
    noctalia.notify(noctalia.tr("notify.title"), noctalia.tr("notify.setup_started"))
    noctalia.runInTerminal("bash '" .. script .. "'")
  end
end)

function onConfigChanged()
  local mode = noctalia.getConfig("display_mode")
  if type(mode) == "string" and mode ~= "" then
    snapshot.display_mode = mode
  end
  local interval = tonumber(noctalia.getConfig("poll_interval_ms")) or 2000
  noctalia.setUpdateInterval(math.clamp(interval, 500, 30000))
  readHardware()
end

function update()
  readHardware()
end

-- Initialize display mode from config
local initialMode = noctalia.getConfig("display_mode")
if type(initialMode) == "string" and initialMode ~= "" then
  snapshot.display_mode = initialMode
end

local initialInterval = tonumber(noctalia.getConfig("poll_interval_ms")) or 2000
noctalia.setUpdateInterval(math.clamp(initialInterval, 500, 30000))

publish()
readHardware()
