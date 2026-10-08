--!nonstrict
-- MacBook Fan & Thermal Bar Widget
-- Declarative bar widget rendering fan speed and thermal status.

local SNAPSHOT = "macbook_fan.snapshot"
local PANEL_ID = "blackx16/macbook-fan:panel"

local snap = noctalia.state.get(SNAPSHOT) or {
  rpm = 0,
  min_rpm = 1200,
  max_rpm = 6500,
  percent = 0,
  temp = 0,
  daemon_active = false,
  driver_available = false,
  display_mode = "rpm",
}

local function getAccentRole()
  if not snap.driver_available then
    return "destructive"
  end

  local colorize = noctalia.getConfig("colorize_by_temp")
  if colorize == false then
    return "primary"
  end

  local t = snap.temp or 0
  local r = snap.rpm or 0
  if t >= 80 or r >= 5000 then
    return "destructive"
  elseif t >= 65 or r >= 3200 then
    return "warning"
  end

  return "primary"
end

local function getDisplayText()
  if not snap.driver_available then
    return "No SMC"
  end

  local mode = snap.display_mode or "rpm"
  if mode == "percent" then
    return string.format("%d%%", snap.percent or 0)
  elseif mode == "both" then
    return string.format("%d RPM · %d%%", snap.rpm or 0, snap.percent or 0)
  else
    return string.format("%d RPM", snap.rpm or 0)
  end
end

local function getStatusText()
  local t = snap.temp or 0
  local r = snap.rpm or 0
  if t >= 80 or r >= 5000 then
    return "Heavy Load (Throttling Risk)"
  elseif t >= 65 or r >= 3200 then
    return "Elevated Temperature"
  end
  return "Normal / Optimal"
end

local function render()
  local isVertical = barWidget.isVertical()
  local accent = getAccentRole()
  local text = getDisplayText()

  local container = isVertical and ui.column or ui.row
  local glyphName = snap.driver_available and "car-fan" or "alert-triangle"

  barWidget.render(container({ gap = 6, align = "center" }, {
    ui.glyph({
      name = glyphName,
      size = 14,
      color = accent,
    }),
    ui.row({
      fill = accent .. "/0.20",
      radius = 8,
      paddingH = 6,
      align = "center",
    }, {
      ui.label({
        text = text,
        color = accent,
        fontWeight = "bold",
        fontSize = 12,
      }),
    }),
  }))

  -- Rich structured tooltip
  barWidget.setTooltip({
    { key = noctalia.tr("tooltip.speed"), value = string.format("%d RPM (%d%%)", snap.rpm or 0, snap.percent or 0) },
    { key = noctalia.tr("tooltip.temperature"), value = string.format("%.1f °C", snap.temp or 0) },
    { key = noctalia.tr("tooltip.limits"), value = string.format("%d – %d RPM", snap.min_rpm or 1200, snap.max_rpm or 6500) },
    { key = noctalia.tr("tooltip.controller"), value = snap.daemon_active and "mbpfan (active)" or "mbpfan (inactive)" },
    { key = noctalia.tr("tooltip.status"), value = getStatusText() },
  })
end

-- Watch state updates from service.luau
noctalia.state.watch(SNAPSHOT, function(value)
  if type(value) == "table" then
    snap = value
    render()
  end
end)

function update()
  render()
end

function onConfigChanged()
  render()
end

function onClick()
  local allowPopup = noctalia.getConfig("allow_popup")
  if allowPopup ~= false then
    noctalia.togglePanel(PANEL_ID)
  end
end

noctalia.setUpdateInterval(5000)
render()
