---@module 'hl'

-- hyprland.lua for Gentoo (omen). Hyprland 0.57 and later read only this
-- file. They ignore hyprland.conf.
--
-- This is the Guix hypr/hyprland.lua (ported from sway) with these changes:
--   - Gentoo paths: polkit agent, PipeWire on OpenRC, D-Bus environment.
--   - The two monitors of the omen.
--   - The "night-train" colors from wallpapers/hyprland-girl.jpg.
--     The same colors are in waybar, fuzzel, swaync, alacritty, hyprlock,
--     GTK (gtk-3.0/gtk-4.0) and Qt (qt6ct). See gentoo/README.md.
--
-- night-train palette (main colors):
--   base #140b33   surface #1e1548   border #3a3380   text #e4e0f7
--   cyan #47aeda   glow #7fd8f2      lavender #ba94c3  indigo #2b3786
--   plum #642c5f   red #f0647f       orange #f2a272

--###############
--## VARIABLES ##
--###############

local mainMod = "SUPER"
local terminal = "alacritty"
local menu = "fuzzel"

--#############
--## MONITOR ##
--#############

-- Any other monitor: preferred mode, placed automatically.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.0,
})

-- Laptop panel.
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@144",
    position = "0x0",
    scale    = 1,
})

-- External monitor, to the right of the laptop panel.
hl.monitor({
    output   = "desc:Sceptre Tech Inc Sceptre F22 0x01010101",
    mode     = "1920x1080@144",
    position = "1920x0",
    scale    = 1,
})

-- Virtual TV monitor for casting.
hl.monitor({
    output   = "CAST",
    mode     = "1920x1080@30",
    position = "10000x0",
    scale    = 1,
})

hl.workspace_rule({
    workspace = 9,
    monitor = "CAST",
    default = true,
})

--##############
--## ENV VARS ##
--##############

hl.env("XCURSOR_THEME", "phinger-cursors-dark")
hl.env("XCURSOR_SIZE", 40)

-- Qt: colors and fonts come from qt6ct (~/.config/qt6ct).
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- Native Wayland for Qt. xcb is the fallback if dev-qt/qtwayland is missing.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", 1)

-- Native Wayland for Electron programs (Bitwarden, ...).
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

-- GTK: no GTK_THEME here. GTK_THEME also changes libadwaita (GTK 4)
-- programs and breaks their colors. scripts/dark-theme.sh sets the dark
-- theme with gsettings, and gtk-3.0/gtk-4.0 settings.ini do the rest.
-- If a GTK 3 program stays light, remove the "--" from the next line.
-- hl.env("GTK_THEME", "adw-gtk3-dark")

--#############
--## INPUT ####
--#############

hl.config({
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
})

--############
--## LOOK ####
--############

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
        col = {
            -- night-train: cyan to lavender (active), indigo (inactive)
            active_border = { colors = { "rgba(47aedaee)", "rgba(ba94c3ee)" }, angle = 45 },
            inactive_border = "rgba(2b3786aa)",
        },
    },
})

hl.config({
    decoration = {
        rounding = 8,
        active_opacity = 1.0,
        inactive_opacity = 0.95,
        blur = {
            enabled = true,
            size = 5,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = true,
        },
        shadow = {
            enabled = true,
            range = 14,
            render_power = 3,
            color = "rgba(0b0620ee)",
        },
    },
})

hl.config({
    animations = {
        enabled = true,
    },
})
hl.curve("easeOutQuint", {
    type = "bezier",
    points = { { 0.23, 1 }, { 0.32, 1 } },
})
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slide" })

-- dwindle = binary-tree auto split, the nearest thing to the default
-- splith of sway.
hl.config({
    dwindle = {
        preserve_split = true,
        smart_split = false,
    },
})

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
    },
})

--############################
--## WINDOW / LAYER RULES ####
--############################

hl.window_rule({
    name  = "float_pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name  = "float_nm_connection_editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name  = "float_blueman",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name  = "float_pip",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
})

hl.window_rule({
    name  = "pin_pip",
    match = { title = "^(Picture-in-Picture)$" },
    pin = true,
})

-- Blur behind the bar, the launcher and the notification panel.
-- Their backgrounds are a little transparent (see their style files).
-- ignore_alpha: no blur where the layer is almost fully transparent
-- (the round corners and the space around the bar).
hl.layer_rule({
    name  = "blur_waybar",
    match = { namespace = "^(waybar)$" },
    blur  = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({
    name  = "blur_fuzzel",
    match = { namespace = "^(launcher)$" },
    blur  = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({
    name  = "blur_swaync",
    match = { namespace = "^(swaync-control-center|swaync-notification-window)$" },
    blur  = true,
    ignore_alpha = 0.2,
})

--###############
--## KEYBINDS ###
--###############

-- --- apps / session ---

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("~/.config/hypr/scripts/exit-hyprland.sh"))

-- Hold mainMod and drag with the mouse.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- --- focus: vim keys and arrows ---

hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))

-- --- move window ---

hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))

-- --- workspaces 1-10 ---
-- mainMod + number: go to the workspace.
-- mainMod + SHIFT + number: move the window there, but stay here (as in sway).

for i = 1, 10 do
    local key = i % 10 -- the 0 key is workspace 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- --- layout ---

hl.bind(mainMod .. " + e", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + f", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.window.float())

-- Groups: the nearest thing to the stacking/tabbed containers of sway.
hl.bind(mainMod .. " + w", hl.dsp.group.toggle())
hl.bind(mainMod .. " + Tab", hl.dsp.group.next())

-- --- scratchpad: the "special" workspace ---

hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratch", follow = false }))
hl.bind(mainMod .. " + minus", hl.dsp.workspace.toggle_special("scratch"))

-- --- resize mode (submap), as the "resize" mode of sway ---

hl.bind(mainMod .. " + r", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
    hl.bind("h", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
    hl.bind("l", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
    hl.bind("k", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
    hl.bind("j", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
    hl.bind("Left", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
    hl.bind("Right", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
    hl.bind("Up", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
    hl.bind("Down", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

-- --- media keys ---
-- repeating: repeats while you hold the key. locked: works on the lock screen.
-- If a key does nothing, run `wev` to find its keycode.

hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true, locked = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })

-- --- screenshots: grim, slurp, swappy ---

hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/$(date +'%Y-%m-%d-%H%M%S').png"))
hl.bind(mainMod .. " + SHIFT + s", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind(mainMod .. " + SHIFT + a", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | swappy -f -"))

--###############
--## AUTOSTART ##
--###############

hl.on("hyprland.start", function()
    -- Give the D-Bus programs (portals, swaync, polkit) the Wayland
    -- variables. --systemd is ignored when systemd is not there (OpenRC).
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    -- OpenRC: start PipeWire with the session. With USE=systemd the
    -- launcher is not installed, and this line does nothing.
    hl.exec_cmd("command -v gentoo-pipewire-launcher >/dev/null && gentoo-pipewire-launcher restart")
    -- Polkit agent. Gentoo installs it in one of these two folders.
    hl.exec_cmd("for p in /usr/libexec/hyprpolkitagent /usr/lib64/libexec/hyprpolkitagent; do [ -x \"$p\" ] && exec \"$p\"; done")
    -- Dark theme for GTK 3, GTK 4 (libadwaita), icons and cursor.
    hl.exec_cmd("~/.config/hypr/scripts/dark-theme.sh")
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("~/.local/bin/nightlight init")
    hl.exec_cmd("udiskie --notify")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
end)

-- quick-settings BEGIN (added by quick-settings.sh, "revert" removes this block)
-- Quick settings panel. Super+S is the same key as in the GNOME test.
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("swaync-client -t -sw"))
-- Night light on or off.
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("~/.local/bin/nightlight toggle"))
-- The panel buttons can open GNOME Settings. Float it, like pavucontrol.
hl.window_rule({
    name  = "float_gnome_settings",
    match = {
        class = "^(org.gnome.Settings)$",
    },
    float = true,
})
-- quick-settings END
