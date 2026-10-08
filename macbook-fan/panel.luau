--!nonstrict
-- MacBook Fan & Thermal Attached Popup Panel
-- Provides detailed telemetry, progress gauges, mode selection, and requirements verification.

local SNAPSHOT = "macbook_fan.snapshot"
local COMMAND = "macbook_fan.command"

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

local function setDisplayMode(mode)
  noctalia.state.set(COMMAND, {
    action = "set_display_mode",
    mode = mode,
  })
end

local function runSetup()
  noctalia.state.set(COMMAND, {
    action = "run_setup",
  })
end

local function getAccentRole()
  if not snap.driver_available then
    return "destructive"
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

local function modeButton(mode, label)
  local current = snap.display_mode or "rpm"
  local isSelected = (current == mode)
  return ui.button({
    text = label,
    variant = isSelected and "primary" or "ghost",
    flexGrow = 1,
    controlSize = "sm",
    onClick = function()
      setDisplayMode(mode)
    end,
  })
end

local function render()
  local accent = getAccentRole()
  local span = math.max(1, (snap.max_rpm or 6500) - (snap.min_rpm or 1200))
  local progressVal = math.clamp(((snap.rpm or 0) - (snap.min_rpm or 1200)) / span, 0, 1)

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    -- 1. Header
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.row({ align = "center", gap = 6 }, {
        ui.glyph({ name = "car-fan", color = accent, size = 18 }),
        ui.label({
          text = noctalia.tr("panel.title"),
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
      }),
      ui.button({
        glyph = "close",
        variant = "ghost",
        controlSize = "sm",
        onClick = function()
          panel.close()
        end,
      }),
    }),

    -- 2. Fan RPM & Gauge
    ui.column({ gap = 6 }, {
      ui.row({ align = "center", justify = "space_between" }, {
        ui.row({ gap = 6, align = "center" }, {
          ui.label({
            text = string.format("%d RPM", snap.rpm or 0),
            fontSize = 18,
            fontWeight = "bold",
            color = accent,
          }),
        }),
        ui.row({
          fill = accent .. "/0.15",
          radius = 6,
          paddingH = 6,
          paddingV = 2,
        }, {
          ui.label({
            text = string.format("%d%%", snap.percent or 0),
            fontSize = 12,
            fontWeight = "bold",
            color = accent,
          }),
        }),
      }),

      ui.progress({
        progress = progressVal,
        height = 8,
        radius = 4,
        fill = accent,
        track = "secondary/0.2",
      }),

      ui.row({ justify = "space_between" }, {
        ui.label({
          text = string.format("%d RPM", snap.min_rpm or 1200),
          fontSize = 10,
          color = "on_surface_variant",
        }),
        ui.label({
          text = noctalia.tr("panel.gauge_limits"),
          fontSize = 10,
          color = "on_surface_variant",
        }),
        ui.label({
          text = string.format("%d RPM", snap.max_rpm or 6500),
          fontSize = 10,
          color = "on_surface_variant",
        }),
      }),
    }),

    -- 3. Telemetry Cards
    ui.column({ gap = 6 }, {
      ui.label({
        text = noctalia.tr("panel.telemetry_title"),
        fontSize = 11,
        fontWeight = "bold",
        color = "on_surface_variant",
      }),
      ui.row({ gap = 8, align = "center" }, {
        ui.row({
          fill = "secondary/0.15",
          radius = 8,
          paddingH = 10,
          paddingV = 6,
          gap = 6,
          flexGrow = 1,
          align = "center",
        }, {
          ui.glyph({ name = "flame", size = 16, color = accent }),
          ui.column({ gap = 2 }, {
            ui.label({ text = noctalia.tr("panel.temperature"), fontSize = 10, color = "on_surface_variant" }),
            ui.label({ text = string.format("%.1f °C", snap.temp or 0), fontSize = 13, fontWeight = "bold", color = "on_surface" }),
          }),
        }),
        ui.row({
          fill = "secondary/0.15",
          radius = 8,
          paddingH = 10,
          paddingV = 6,
          gap = 6,
          flexGrow = 1,
          align = "center",
        }, {
          ui.glyph({ name = "cpu", size = 16, color = "primary" }),
          ui.column({ gap = 2 }, {
            ui.label({ text = noctalia.tr("panel.controller"), fontSize = 10, color = "on_surface_variant" }),
            ui.label({
              text = snap.daemon_active and "mbpfan active" or "mbpfan stopped",
              fontSize = 13,
              fontWeight = "bold",
              color = snap.daemon_active and "primary" or "warning",
            }),
          }),
        }),
      }),
    }),

    -- 4. Display Mode Switcher
    ui.column({ gap = 6 }, {
      ui.label({
        text = noctalia.tr("panel.display_mode"),
        fontSize = 11,
        fontWeight = "bold",
        color = "on_surface_variant",
      }),
      ui.row({ gap = 6 }, {
        modeButton("rpm", noctalia.tr("panel.mode_rpm")),
        modeButton("percent", noctalia.tr("panel.mode_percent")),
        modeButton("both", noctalia.tr("panel.mode_both")),
      }),
    }),

    -- 5. Requirements & Setup Action
    ui.column({ gap = 6 }, {
      ui.label({
        text = noctalia.tr("panel.prereqs_title"),
        fontSize = 11,
        fontWeight = "bold",
        color = "on_surface_variant",
      }),
      ui.row({
        fill = "secondary/0.15",
        radius = 8,
        paddingH = 10,
        paddingV = 6,
        align = "center",
        justify = "space_between",
      }, {
        ui.column({ gap = 2 }, {
          ui.label({
            text = snap.driver_available and "Driver: applesmc loaded" or "Driver: missing applesmc",
            fontSize = 11,
            color = snap.driver_available and "on_surface" or "destructive",
          }),
          ui.label({
            text = snap.daemon_active and "Service: mbpfan running" or "Service: mbpfan inactive",
            fontSize = 11,
            color = snap.daemon_active and "on_surface" or "warning",
          }),
        }),
        ui.button({
          text = "Setup",
          glyph = "tool",
          variant = "secondary",
          controlSize = "sm",
          onClick = runSetup,
        }),
      }),
    }),
  }))
end

function onOpen(_context)
  snap = noctalia.state.get(SNAPSHOT) or snap
  render()
end

noctalia.state.watch(SNAPSHOT, function(val)
  if type(val) == "table" then
    snap = val
    render()
  end
end)

function update()
  render()
end

render()
