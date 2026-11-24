-- ~/.config/xmonad/xmonad.hs
-- Targets xmonad / xmonad-contrib 0.17+ (Ubuntu 22.04 and newer, FreeBSD
-- with the Hackage libraries, see xmonad/build).
-- Mod key = Super. Reload with Super+q after editing.

import           System.Info                     (os)
import           XMonad
import qualified XMonad.StackSet                 as W

import           XMonad.Actions.CycleWS          (toggleWS)
import           XMonad.Hooks.EwmhDesktops       (ewmh, ewmhFullscreen)
import           XMonad.Hooks.ManageDocks        (avoidStruts)
import           XMonad.Hooks.ManageHelpers      (doCenterFloat, doFullFloat,
                                                  isDialog, isFullscreen)
import           XMonad.Hooks.StatusBar
import           XMonad.Hooks.StatusBar.PP
import           XMonad.Layout.NoBorders         (smartBorders)
import           XMonad.Layout.Renamed           (Rename (Replace), renamed)
import           XMonad.Layout.Spacing           (Border (..), spacingRaw)
import           XMonad.Layout.ToggleLayouts     (ToggleLayout (..),
                                                  toggleLayouts)
import           XMonad.Util.ClickableWorkspaces (clickablePP)
import           XMonad.Util.EZConfig            (additionalKeysP)
import           XMonad.Util.SpawnOnce           (spawnOnce)

------------------------------------------------------------------------
-- Apps

myTerminal, myBrowser, myFiles, myLauncher, myLocker :: String
myTerminal = "alacritty"
myBrowser  = "firefox"
myFiles    = "nautilus"
myLauncher = "rofi -show drun -show-icons"
myLocker   = "xscreensaver-command -lock"   -- xscreensaver starts in autostart.sh

-- Volume and brightness: PipeWire and brightnessctl on Linux (the gram),
-- mixer(8) and backlight(8) on FreeBSD (the Panasonic). On the Panasonic the
-- Fn keys are ACPI events, not X keys: devd runs the same commands for them.
-- These bindings are for keyboards that send the XF86 keys.
onFreeBSD :: Bool
onFreeBSD = os == "freebsd"

volUp, volDown, volMute, micMute, brightUp, brightDown :: String
volUp      | onFreeBSD = "mixer vol.volume=+5%"
           | otherwise = "pactl set-sink-volume @DEFAULT_SINK@ +5%"
volDown    | onFreeBSD = "mixer vol.volume=-5%"
           | otherwise = "pactl set-sink-volume @DEFAULT_SINK@ -5%"
volMute    | onFreeBSD = "mixer vol.mute=toggle"
           | otherwise = "pactl set-sink-mute @DEFAULT_SINK@ toggle"
micMute    | onFreeBSD = "mixer rec.mute=toggle"
           | otherwise = "pactl set-source-mute @DEFAULT_SOURCE@ toggle"
brightUp   | onFreeBSD = "backlight incr 5"
           | otherwise = "brightnessctl set +5%"
brightDown | onFreeBSD = "backlight decr 5"
           | otherwise = "brightnessctl set 5%-"

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
    gaps = spacingRaw True (Border 4 4 4 4) True (Border 4 4 4 4) True
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
  , ("<XF86AudioRaiseVolume>",  spawn volUp)
  , ("<XF86AudioLowerVolume>",  spawn volDown)
  , ("<XF86AudioMute>",         spawn volMute)
  , ("<XF86AudioMicMute>",      spawn micMute)
  , ("<XF86MonBrightnessUp>",   spawn brightUp)
  , ("<XF86MonBrightnessDown>", spawn brightDown)
  , ("<XF86AudioPlay>",         spawn "playerctl play-pause")
  , ("<XF86AudioNext>",         spawn "playerctl next")
  , ("<XF86AudioPrev>",         spawn "playerctl previous")
  ]

------------------------------------------------------------------------
-- Status bar (xmobar reads ~/.config/xmobar/xmobarrc)

-- Left side of the bar: Qubes OS's i3bar workspace buttons in cccru colours.
-- Only workspaces in use are shown (current, with windows, or urgent), each
-- as a filled box with a 1px border, 1px apart, like i3bar.
-- Clicking a button switches to it (clickablePP, needs xdotool). No layout
-- name or window title, as in i3bar.
--            border      fill    text       (i3bar colours class)
myPP :: PP
myPP = def
  { ppCurrent         = wsButton cNeonDim  cNeon  cBg     -- focused_workspace
  , ppVisible         = wsButton cMint     cDark  cInk    -- active_workspace (other monitor)
  , ppHidden          = wsButton cDark     cBg    cMuted  -- inactive_workspace
  , ppHiddenNoWindows = const ""                          -- i3 hides empty workspaces
  , ppUrgent          = wsButton "#ff6b6b" cFaint cBg     -- urgent_workspace
  , ppWsSep           = "<hspace=1/>"
  , ppSep             = ""
  , ppOrder           = take 1                            -- workspaces only
  }

-- A workspace button: " name " filled with the fill colour, inside a 1px
-- border box.
-- xmobar paints a text's background only as tall as that text's font, so
-- the padding spaces use the same font as the number; a smaller font for
-- them gave a cross-shaped fill. The fill is the font's line height (rows
-- 1-18 of the 24px bar), and the box is 23px tall, so mb=3 pulls its bottom
-- border up to sit right under the fill.
wsButton :: String -> String -> String -> String -> String
wsButton border fill text name =
  "<box type=Full width=1 mt=1 mb=3 color=" ++ border ++ ">"
    ++ xmobarColor text fill (" " ++ name ++ " ")
    ++ "</box>"

mySB :: StatusBarConfig
mySB = statusBarProp "xmobar" (clickablePP myPP)

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
