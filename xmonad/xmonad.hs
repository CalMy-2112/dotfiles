-- ~/.config/xmonad/xmonad.hs
-- Targets xmonad / xmonad-contrib 0.17+ (Ubuntu 22.04 and newer).
-- Mod key = Super. Reload with Super+q after editing.

import XMonad
import qualified XMonad.StackSet as W

import XMonad.Actions.CycleWS (toggleWS)
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageDocks (avoidStruts)
import XMonad.Hooks.ManageHelpers (doCenterFloat, doFullFloat, isDialog, isFullscreen)
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Layout.NoBorders (smartBorders)
import XMonad.Layout.Renamed (Rename (Replace), renamed)
import XMonad.Layout.Spacing (Border (..), spacingRaw)
import XMonad.Layout.ToggleLayouts (ToggleLayout (..), toggleLayouts)
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Util.Loggers (logCmd)
import XMonad.Util.SpawnOnce (spawnOnce)

------------------------------------------------------------------------
-- Apps

myTerminal, myBrowser, myFiles, myLauncher, myLocker :: String
myTerminal = "alacritty"
myBrowser  = "firefox"
myFiles    = "nautilus"
myLauncher = "rofi -show drun -show-icons"
myLocker   = "loginctl lock-session"   -- handled by xss-lock in autostart.sh

------------------------------------------------------------------------
-- Colours, from cccru.ca's style.css (neon green on black)

cBg, cInk, cMuted, cNeon, cNeonDim, cDark, cMint, cPale, cFaint :: String
cBg      = "#0b0b0b"   -- --bg
cInk     = "#e9efe9"   -- --ink
cMuted   = "#b7c9b7"   -- --muted
cNeon    = "#11ff7a"   -- --neon
cNeonDim = "#0bbf5b"   -- --neon-dim
cDark    = "#2d732d"   -- --darkened
cMint    = "#6fd495"
cPale    = "#9bd8ae"
cFaint   = "#afffd6"

------------------------------------------------------------------------
-- Layouts
--   Tall: main window left, stack right
--   Wide: main window top, stack below
--   Full: one window at a time
-- Super+Space cycles them, Super+f toggles fullscreen-ish Full on any of them.

myLayout = avoidStruts . smartBorders . toggleLayouts Full $ tall ||| wide ||| full
  where
    gaps = spacingRaw True (Border 6 6 6 6) True (Border 6 6 6 6) True
    tall = renamed [Replace "Tall"] . gaps $ Tall 1 (3 / 100) (1 / 2)
    wide = renamed [Replace "Wide"] . gaps $ Mirror (Tall 1 (3 / 100) (1 / 2))
    full = renamed [Replace "Full"] Full

------------------------------------------------------------------------
-- Window rules  (find a window's class with: xprop | grep WM_CLASS, then click it)

myManageHook :: ManageHook
myManageHook = composeAll
  [ isDialog                              --> doCenterFloat
  , isFullscreen                          --> doFullFloat
  , className =? "Pavucontrol"            --> doCenterFloat
  , className =? "Nm-connection-editor"   --> doCenterFloat
  , className =? "Blueman-manager"        --> doCenterFloat
  , className =? "Gnome-calculator"       --> doCenterFloat
  , className =? "flameshot"              --> doFloat
  , className =? "Pinentry"               --> doCenterFloat
  ]

------------------------------------------------------------------------
-- Keys (added on top of the xmonad defaults; see Super+Shift+/ for those)

myKeys :: [(String, X ())]
myKeys =
  -- apps
  [ ("M-<Return>",   spawn myTerminal)
  , ("M-S-<Return>", windows W.swapMaster)   -- default moved here
  , ("M-p",          spawn myLauncher)
  , ("M-S-p",        spawn "rofi -show run")
  , ("M-S-b",        spawn myBrowser)
  , ("M-o",          spawn myFiles)
  , ("M-C-l",        spawn myLocker)

  -- windows / layouts
  , ("M-S-c",        kill)
  , ("M-f",          sendMessage ToggleLayout)
  , ("M-<Tab>",      toggleWS)                -- jump to previous workspace
  , ("M-S-t",        withFocused $ windows . W.sink)  -- re-tile a floating window

  -- screenshots
  , ("M-S-s",        spawn "flameshot gui")
  , ("<Print>",      spawn "flameshot gui")
  , ("S-<Print>",    spawn "flameshot full")

  -- media keys
  , ("<XF86AudioRaiseVolume>",  spawn "pactl set-sink-volume @DEFAULT_SINK@ +5%")
  , ("<XF86AudioLowerVolume>",  spawn "pactl set-sink-volume @DEFAULT_SINK@ -5%")
  , ("<XF86AudioMute>",         spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle")
  , ("<XF86AudioMicMute>",      spawn "pactl set-source-mute @DEFAULT_SOURCE@ toggle")
  , ("<XF86MonBrightnessUp>",   spawn "brightnessctl set +5%")
  , ("<XF86MonBrightnessDown>", spawn "brightnessctl set 5%-")
  , ("<XF86AudioPlay>",         spawn "playerctl play-pause")
  , ("<XF86AudioNext>",         spawn "playerctl next")
  , ("<XF86AudioPrev>",         spawn "playerctl previous")
  ]

------------------------------------------------------------------------
-- Status bar (xmobar reads ~/.config/xmobar/xmobarrc)

-- Left side of the bar:   [ 1  2  3 ... 9 ]  |  [tray icons]  |  window title
-- Every workspace is exactly 3 characters wide (" n "), so the workspace
-- block is always 27 characters. trayer is placed at a fixed pixel offset
-- right after it (see the trayer line in autostart.sh), and the padding
-- logger leaves a gap as wide as the tray before the title.
myPP :: PP
myPP = def
  { ppCurrent         = xmobarColor cBg cNeon . pad3   -- black on neon, like a lit button
  , ppVisible         = xmobarColor cBg cMint . pad3   -- shown on another monitor
  , ppHidden          = xmobarColor cMuted "" . pad3
  , ppHiddenNoWindows = xmobarColor cDark "" . pad3
  , ppUrgent          = xmobarColor cBg cFaint . pad3
  , ppWsSep           = ""
  , ppTitle           = xmobarColor cPale "" . shorten 70
  , ppSep             = xmobarColor cDark "" "  |  "
  , ppExtras          = [logCmd "~/.config/xmobar/trayer-padding.sh"]
  , ppOrder           = \xs -> case xs of
                          (ws : _layout : title : extras) -> ws : extras ++ [title]
                          _                               -> xs
  }
  where
    pad3 = wrap " " " "

mySB :: StatusBarConfig
mySB = statusBarProp "xmobar" (pure myPP)

------------------------------------------------------------------------

myStartupHook :: X ()
myStartupHook = spawnOnce "~/.config/xmonad/autostart.sh"

myConfig = def
  { modMask            = mod4Mask      -- Super
  , terminal           = myTerminal
  , borderWidth        = 2
  , normalBorderColor  = cDark
  , focusedBorderColor = cNeon
  , focusFollowsMouse  = True
  , clickJustFocuses   = False
  , layoutHook         = myLayout
  , manageHook         = myManageHook <+> manageHook def
  , startupHook        = myStartupHook
  }
  `additionalKeysP` myKeys

-- Super+b toggles the bar's reserved space (defToggleStrutsKey)
main :: IO ()
main = xmonad
     . ewmhFullscreen
     . ewmh
     . withEasySB mySB defToggleStrutsKey
     $ myConfig
