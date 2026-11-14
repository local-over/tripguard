# Brand Identity & Design System Specification: TripGuard

This document specifies the exact visual identity, design tokens, typography, component layouts, and animation standards derived from deep analysis of *TripMode 3* and *Cafaine* for the 100% free and open-source macOS per-app network firewall and bandwidth controller **TripGuard**.

---

## 1. Color Palette & Design Tokens

### Primary Brand Gradient (App Icon & Marketing)
- **Top / Light Accent:** `#00D68F` (Electric Signal Emerald, RGB: 0, 214, 143)
- **Mid / Core Accent:** `#0095FF` (Vibrant Sky Cyan, RGB: 0, 149, 255)
- **Bottom / Deep Accent:** `#0B3996` (Deep Royal Cobalt, RGB: 11, 57, 150)
- **Gradient Angle:** 135 degrees (top-left to bottom-right)
- **Foreground Glyphs:** `#FFFFFF` (Pure White, 100% opacity)

### Interface Chrome (macOS Native Materials)
- **Light Mode Menu Background:** `NSVisualEffectView.Material.popover` (translucent light material, base `#FFFFFF` with blur)
- **Dark Mode Menu Background:** `NSVisualEffectView.Material.popover` (translucent dark material, base `#16181F` with blur)
- **Primary Text Color (Light):** `#1D1D1F` (macOS Primary Label, 100% opacity)
- **Secondary Text Color (Light):** `#86868B` (macOS Secondary Label, 60% opacity)
- **Primary Text Color (Dark):** `#F5F5F7` (macOS Primary Label, 100% opacity)
- **Secondary Text Color (Dark):** `#A1A1A6` (macOS Secondary Label, 65% opacity)
- **Active Shield / Allowed State Tint:** `#007AFF` (Apple System Blue) & `#00C48C` (Signal Emerald)
- **Blocked / Cutoff State Tint:** `#FF3B30` (Apple System Red)

---

## 2. Typography

All typography strictly adheres to Apple Human Interface Guidelines using the system font:

- **Application Title:** SF Pro Display, 14pt, Bold
- **Network Status Subtitle ("Shield Active • iPhone Hotspot"):** SF Pro Text, 11pt, Medium
- **Live Bandwidth Counters ("↓ 1.2 MB/s  ↑ 84 KB/s"):** SF Pro Text, 11pt, Monospaced Digits, Semi-Bold
- **Data Cap Pills ("∞", "100M", "250M", "500M", "1G", "2G", "5G"):** SF Pro Text, 10pt, Monospaced Digits, Medium
- **App Row Titles:** SF Pro Text, 12pt, Medium
- **App Row Traffic Subtitles:** SF Pro Text, 10pt, Monospaced Digits, Regular
- **Settings Section Headers:** SF Pro Text, 12pt, Medium

*Strict Rule:* No emoji glyphs are permitted anywhere in application menus, status titles, settings labels, or marketing assets. All iconography uses crisp SF Symbols or custom CoreGraphics vector paths.

---

## 3. Menu Bar Icon & Animation Specifications

### Inactive State (Shield Off)
- **Icon:** A minimal 18x18 vector shield outline with an internal network node cross:
  - Shield contour: Smooth curved crest with rounded top corners and pointed base.
  - Fill: Transparent.
  - Rendering Mode: Template (automatic dark/light adaptation).

### Active State (Shield On) & Signal Pulse Animation
- **Fill:** Shield body filled solid with monochrome template or Brand Cyan/Emerald when colored icon mode is active.
- **Data Wave Animation:**
  - 4 discrete animation frames cycling at 180ms intervals.
  - Radiating signal arcs on the top-right crest of the shield pulsing outward as live network packets are filtered.
  - Optional live menu bar rate/usage text (`142 MB` or `↓ 480 KB/s`) rendered in monospaced tabular digits next to the icon.

---

## 4. Menu & Popover Architecture

```
+---------------------------------------------------+
|  TripGuard                      ↓ 420 KB/s   (•)  |
|  ● Shield Active • Wi-Fi (en0)                    |
+---------------------------------------------------+
|  Session Data: 142.4 MB / 500 MB (28%)       [↺]  |
|  [==========------------------------]   38 Blocked|
|  Data Cap                          Profile: [Work]|
|  [ ∞ ] [100M] [250M] [•500M] [ 1G ] [ 2G ] [5G][⚙]|
+---------------------------------------------------+
|  Apps (4 Allowed, 5 Blocked)   [All] [Active] [🔒]|
|  [Chrome Icon]  Google Chrome      84.2 MB   (•)  |
|  [Slack Icon]   Slack              19.4 MB   (•)  |
|  [Dropbox Icon] Dropbox           Blocked    ( )  |
|  [Photos Icon]  Photos        14 Stopped     ( )  |
+---------------------------------------------------+
|  Settings                                      >  |
+---------------------------------------------------+
|  Detach Live Monitor Window                       |
|  Donate (PayPal / Crypto)                         |
|  Website & Documentation                          |
|  About                                            |
|  Quit                                             |
+---------------------------------------------------+
```
