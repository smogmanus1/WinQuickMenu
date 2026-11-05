#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

;@Ahk2Exe-SetName WinQuickMenu
;@Ahk2Exe-SetDescription WinQuickMenu - Windows shortcut menu and idle hibernate
;@Ahk2Exe-SetVersion 1.0.0
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Brad Schrunk - MIT License

; ==============================================================================
; WinQuickMenu
; One popup menu (and matching hotstrings) for the Windows tools, settings
; pages and power actions you can never find - plus an optional idle-hibernate
; watcher that works even when apps keep Windows awake.
;
; Type  rdmenu  anywhere (or double-click the tray icon) to open the menu.
; Every menu item shows its hotstring in ( ) so you learn them as you go.
;
; Settings live in WinQuickMenu.ini next to the script/exe (created on first run).
; https://github.com/smogmanus1/WinQuickMenu
; ==============================================================================

global AppName    := "WinQuickMenu"
global AppVersion := "1.0.0"
global AppUrl     := "https://github.com/smogmanus1/WinQuickMenu"
global IniFile    := A_ScriptDir "\" AppName ".ini"
global LogFile    := A_ScriptDir "\" AppName ".log"

; Idle hibernate settings (overwritten by the INI file)
global IdleEnabled  := false
global IdleLimitMin := 90
global WarnMin      := 2
global LastWake     := A_TickCount   ; script start and every resume count as activity
global MenuPosition := "TopRight"    ; where rdmenu opens: TopRight, TopLeft or Mouse
global PanelTitle   := "WinQuickMenu Panel"
global Panel        := ""            ; the pinned panel window (built on first use)
global PanelFilter  := "", PanelTree := "", PanelItems := Map()
global IdleMenuLabel := ""

LoadSettings()

; ==============================================================================
; COMMAND TABLE
; [ Category, Menu label, Hotstring, Action ]
; Action is either a command line (string) for Run, or a function.
; A label of "-" adds a separator line.
; Hotstrings ending in "p" avoid clashing with real command names you type.
; ==============================================================================
Categories := [ "Power", "Control Panel", "System Tools", "System Properties"
              , "Display and Input", "File Explorer", "Network", "Hardware"
              , "Quick Actions", "Utilities" ]

Commands := [
    ; --- Power ---
    ["Power", "Shut down now",                "sdnow",      "shutdown /s /t 0"],
    ["Power", "Restart now",                  "restpc",     "shutdown /r /t 0"],
    ["Power", "Hibernate now",                "hibnow",     HibernateNow],
    ["Power", "Sleep now",                    "sleepnow",   SleepNow],
    ["Power", "Lock screen",                  "screenlock", "rundll32.exe user32.dll,LockWorkStation"],
    ["Power", "Sign out",                     "logoffp",    "shutdown /l"],
    ["Power", "-"],
    ["Power", "Shut down in 1 hour",          "sd1hr",      ShutdownTimer],
    ["Power", "Cancel scheduled shutdown",    "sdcancel",   ShutdownCancel],

    ; --- Control Panel ---
    ["Control Panel", "Control Panel",            "cpcp",       "control"],
    ["Control Panel", "Programs and Features",    "addremove",  "control appwiz.cpl"],
    ["Control Panel", "Date and Time",            "datetimep",  "control timedate.cpl"],
    ["Control Panel", "Device Manager",           "devmgrp",    "devmgmt.msc"],
    ["Control Panel", "Power Options",            "powerprop",  "control powercfg.cpl"],
    ["Control Panel", "Region and Language",      "reglang",    "control intl.cpl"],
    ["Control Panel", "User Accounts",            "useracc",    "control userpasswords"],
    ["Control Panel", "Windows Update",           "sysupdate",  "ms-settings:windowsupdate"],
    ["Control Panel", "-"],
    ["Control Panel", "God Mode (all settings)",  "godmode",    GodMode],

    ; --- System Tools ---
    ["System Tools", "Task Manager",              "taskmgrp",     "taskmgr"],
    ["System Tools", "Resource Monitor",          "resmonp",      "resmon"],
    ["System Tools", "Event Viewer",              "eventview",    "eventvwr.msc"],
    ["System Tools", "Services",                  "servicesprog", "services.msc"],
    ["System Tools", "Task Scheduler",            "tasksched",    "taskschd.msc"],
    ["System Tools", "Computer Management",       "compmgmtp",    "compmgmt.msc"],
    ["System Tools", "Disk Management",           "diskmgmtp",    "diskmgmt.msc"],
    ["System Tools", "Disk Cleanup",              "diskclean",    "cleanmgr"],
    ["System Tools", "System Information",        "sysinfo",      "msinfo32"],
    ["System Tools", "Registry Editor",           "regeditp",     "regedit"],
    ["System Tools", "Run idle maintenance tasks","idletask",     "rundll32.exe advapi32.dll,ProcessIdleTasks"],

    ; --- System Properties ---
    ["System Properties", "Computer name / domain",  "sysprop",    "SystemPropertiesComputerName.exe"],
    ["System Properties", "Advanced (performance, environment variables)", "sysadvance", "SystemPropertiesAdvanced.exe"],
    ["System Properties", "System Protection (restore points)", "sysprotect", "SystemPropertiesProtection.exe"],
    ["System Properties", "Remote settings",         "sysremote",  "SystemPropertiesRemote.exe"],
    ["System Properties", "-"],
    ["System Properties", "About Windows (version)", "winabout",   "winver"],
    ["System Properties", "Windows Security",        "winsec",     "windowsdefender:"],

    ; --- Display and Input ---
    ["Display and Input", "Display settings",        "displayset", "ms-settings:display"],
    ["Display and Input", "Screen resolution (classic)", "screenres", "control desk.cpl"],
    ["Display and Input", "Night light",             "nightlight", "ms-settings:nightlight"],
    ["Display and Input", "Taskbar settings",        "taskprop",   "ms-settings:taskbar"],
    ["Display and Input", "-"],
    ["Display and Input", "Mouse properties",        "mouseprop",  "control main.cpl"],
    ["Display and Input", "Keyboard properties",     "kbprop",     "rundll32.exe shell32.dll,Control_RunDLL main.cpl @1"],
    ["Display and Input", "Sound devices",           "soundprop",  "control mmsys.cpl"],
    ["Display and Input", "Accessibility",           "handycap",   "ms-settings:easeofaccess"],

    ; --- File Explorer ---
    ["File Explorer", "Folder Options - General",    "folderop",      "rundll32.exe shell32.dll,Options_RunDLL 0"],
    ["File Explorer", "Folder Options - View",       "folderset",     "rundll32.exe shell32.dll,Options_RunDLL 7"],
    ["File Explorer", "Folder Options - Search",     "foldersetting", "rundll32.exe shell32.dll,Options_RunDLL 2"],
    ["File Explorer", "Default apps / file types",   "filetypep",     "ms-settings:defaultapps"],

    ; --- Network ---
    ["Network", "Network Connections (adapters)",    "netprop",   "control ncpa.cpl"],
    ["Network", "Network status",                    "netreset",  "ms-settings:network-status"],
    ["Network", "Wi-Fi settings",                    "wifiset",   "ms-settings:network-wifi"],
    ["Network", "Map Network Drive",                 "mapdrive",  "rundll32.exe shell32.dll,SHHelpShortcuts_RunDLL Connect"],
    ["Network", "Windows Firewall",                  "winfw",     "control firewall.cpl"],
    ["Network", "Internet Options",                  "ieprop",    "control inetcpl.cpl"],
    ["Network", "-"],
    ["Network", "Flush DNS cache",                   "flushdns",  "cmd.exe /k ipconfig /flushdns"],

    ; --- Hardware ---
    ["Hardware", "Safely Remove Hardware",           "ejectdev",  "rundll32.exe shell32.dll,Control_RunDLL hotplug.dll"],
    ["Hardware", "Printers and scanners",            "prman",     "ms-settings:printers"],

    ; --- Quick Actions ---
    ["Quick Actions", "Empty Recycle Bin",           "emptybin",   EmptyRecycleBin],
    ["Quick Actions", "Downloads folder",            "downloadsp", "shell:downloads"],
    ["Quick Actions", "Startup folder",              "startupp",   "shell:startup"],
    ["Quick Actions", "Temp folder",                 "tempfolder", OpenTempFolder],
    ["Quick Actions", "-"],
    ["Quick Actions", "Snipping Tool",               "snipp",      "snippingtool"],
    ["Quick Actions", "Screen snip",                 "prtsc",      "ms-screenclip:"],
    ["Quick Actions", "Calculator",                  "calcp",      "calc"],
    ["Quick Actions", "Notepad",                     "notepadp",   "notepad"],
    ["Quick Actions", "Paint",                       "paintp",     "mspaint"],
    ["Quick Actions", "-"],
    ["Quick Actions", "Clear clipboard",             "clipclear",  ClearClipboard],
    ["Quick Actions", "Clipboard history",           "cliphist",   ClipboardHistory],

    ; --- Utilities ---
    ["Utilities", "Stored user names and passwords", "storedpass", "rundll32.exe keymgr.dll,KRShowKeyMgr"],
    ["Utilities", "Fonts folder",                    "winfont",    "shell:fonts"]
]

; ==============================================================================
; BUILD MENUS AND HOTSTRINGS FROM THE TABLE
; ==============================================================================
global Menus := Map()
global CmdList := []   ; every command, for the pinned panel
for cat in Categories
    Menus[cat] := Menu()

; Command hotstrings are switched off while you type in the panel's search box
HotIfWinNotActive(PanelTitle " ahk_class AutoHotkeyGUI")

for c in Commands {
    m := Menus[c[1]]
    if (c[2] = "-") {
        m.Add()
        continue
    }
    label  := c[3] != "" ? c[2] " (" c[3] ")" : c[2]
    action := MakeAction(c[4])
    m.Add(label, action)
    CmdList.Push({cat: c[1], label: c[2], hs: c[3], action: action})
    if (c[3] != "")
        Hotstring("::" c[3], action)
}

; Idle hibernate controls at the bottom of the Power menu
IdleMenuLabel := "Idle hibernate after " IdleLimitMin " min (hibpause)"
Menus["Power"].Add()
Menus["Power"].Add(IdleMenuLabel, (*) => ToggleIdle())
Menus["Power"].Add("Idle hibernate status (hibstat)", (*) => ShowHibStat())
UpdateIdleCheck()
HotIf()
CmdList.Push({cat: "Power", label: "Idle hibernate on/off", hs: "hibpause", action: (*) => ToggleIdle()})
CmdList.Push({cat: "Power", label: "Idle hibernate status", hs: "hibstat",  action: (*) => ShowHibStat()})

; --- Popup menu (rdmenu) ---
global PopupMenu := Menu()
PopupMenu.Add("✕   Close menu", (*) => 0)   ; clicking any item closes the menu (so does Esc)
PopupMenu.Add()
PopupMenu.Add(AppName "  -  hotstring in ( )", (*) => 0)
PopupMenu.Disable(AppName "  -  hotstring in ( )")
PopupMenu.Add()
for cat in Categories
    PopupMenu.Add(cat, Menus[cat])
PopupMenu.Add()
PopupMenu.Add("Pin as panel - always on top (rdpin)", (*) => TogglePanel())
PopupMenu.Add("About " AppName, (*) => ShowAbout())
PopupMenu.Add()
PopupMenu.Add("✕   Close", (*) => 0)

; --- Tray menu ---
A_TrayMenu.Delete()
A_TrayMenu.Add("Show menu (rdmenu)", (*) => ShowPopupMenu())
A_TrayMenu.Add("Pin as panel - always on top (rdpin)", (*) => TogglePanel())
A_TrayMenu.Add()
for cat in Categories
    A_TrayMenu.Add(cat, Menus[cat])
A_TrayMenu.Add()
A_TrayMenu.Add("Open settings file", (*) => SafeRun('notepad.exe "' IniFile '"'))
A_TrayMenu.Add("About " AppName, (*) => ShowAbout())
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show menu (rdmenu)"
A_IconTip := AppName " " AppVersion "`nType rdmenu or double-click for the menu"

; --- Special hotstrings rdmenu / hibpause / hibstat are defined below,
;     in the CONTROL HOTSTRINGS section after the auto-execute section ---

; --- Idle watcher ---
OnMessage(0x218, OnPowerBroadcast)   ; WM_POWERBROADCAST - detect resume

; Reopen the pinned panel if it was open last time
if (IniRead(IniFile, "Panel", "Open", "0") = "1")
    TogglePanel()
SetTimer(CheckIdle, 15000)           ; check every 15 seconds

return  ; end of auto-execute section


; ==============================================================================
; CONTROL HOTSTRINGS
; These fire as soon as you finish typing them - no Space or Enter needed.
; (The 70 command hotstrings like calcp and hibnow are built from the
;  Commands table at the top of the script.)
; ==============================================================================
:*:rdmenu:: {
    ShowPopupMenu()
}

:*:hibpause:: {
    ToggleIdle()
}

:*:hibstat:: {
    ShowHibStat()
}

:*:rdpin:: {
    TogglePanel()
}


; ==============================================================================
; HELPERS
; ==============================================================================
MakeAction(target) {
    if (Type(target) = "String")
        return (*) => SafeRun(target)
    return (*) => target()
}

SafeRun(cmd) {
    try Run(cmd)
    catch as e
        MsgBox("Could not run:`n" cmd "`n`n" e.Message, AppName, "Icon! T8")
}

ShowPopupMenu() {
    if (MenuPosition = "Mouse") {
        PopupMenu.Show()   ; at the mouse pointer
        return
    }
    ; Corner of the monitor the mouse is on (work area, so it stays clear of
    ; a taskbar placed at the top). Windows shifts the menu left as needed
    ; to keep it on screen, and opens submenus to the left.
    CoordMode("Mouse", "Screen")
    CoordMode("Menu", "Screen")
    MouseGetPos(&mx, &my)
    mon := MonitorGetPrimary()
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (mx >= l && mx < r && my >= t && my < b) {
            mon := A_Index
            break
        }
    }
    MonitorGetWorkArea(mon, &left, &top, &right, &bottom)
    if (MenuPosition = "TopLeft")
        PopupMenu.Show(left, top)
    else
        PopupMenu.Show(right - 1, top)
}

; ==============================================================================
; PINNED PANEL  (rdpin)
; A small always-on-top window in the top-right corner that stays open.
; Type in the box to filter, double-click or press Enter to run a command.
; ==============================================================================
TogglePanel() {
    global Panel
    if (Panel && WinExist("ahk_id " Panel.Hwnd)) {
        ClosePanel()
        return
    }
    if !Panel
        BuildPanel()
    PanelFilter.Value := ""
    FillPanel("")
    Panel.Show("Hide AutoSize")
    Panel.GetPos(, , &w, &h)
    x := IniRead(IniFile, "Panel", "X", "")
    y := IniRead(IniFile, "Panel", "Y", "")
    if (x = "" || y = "") {
        MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
        x := right - w - 8
        y := top + 8
    }
    Panel.Show("x" x " y" y)
    PanelFilter.Focus()
    try IniWrite("1", IniFile, "Panel", "Open")
}

BuildPanel() {
    global Panel, PanelFilter, PanelTree, PanelItems
    Panel := Gui("+AlwaysOnTop +ToolWindow", PanelTitle)
    Panel.SetFont("s11", "Segoe UI")
    Panel.MarginX := 8, Panel.MarginY := 8
    Panel.Add("Text", "w300", "Search (or scroll), then double-click:")
    PanelFilter := Panel.Add("Edit", "w300")
    PanelFilter.OnEvent("Change", (ctrl, *) => FillPanel(ctrl.Value))
    PanelTree := Panel.Add("TreeView", "w300 h480")
    PanelTree.OnEvent("DoubleClick", (ctrl, item) => RunPanelItem(item))
    Panel.Add("Button", "w146 Default", "Run").OnEvent("Click", (*) => RunPanelItem(PanelTree.GetSelection()))
    Panel.Add("Button", "x+8 w146", "Unpin / Close").OnEvent("Click", (*) => ClosePanel())
    Panel.OnEvent("Close", (*) => ClosePanel())
    Panel.OnEvent("Escape", (*) => ClosePanel())
    PanelItems := Map()
}

FillPanel(filter) {
    global PanelItems
    tv := PanelTree
    tv.Opt("-Redraw")
    tv.Delete()
    PanelItems := Map()
    parents := Map()
    for cmd in CmdList {
        text := cmd.hs != "" ? cmd.label "   (" cmd.hs ")" : cmd.label
        if (filter != "" && !InStr(text " " cmd.cat, filter))
            continue
        if !parents.Has(cmd.cat)
            parents[cmd.cat] := tv.Add(cmd.cat, 0, "Bold" (filter != "" ? " Expand" : ""))
        id := tv.Add(text, parents[cmd.cat])
        PanelItems[id] := cmd.action
    }
    ; With a search, select the first match so Enter runs it
    if (filter != "") {
        for id in PanelItems {
            tv.Modify(id, "Select Vis")
            break
        }
    }
    tv.Opt("+Redraw")
}

RunPanelItem(item) {
    if !item
        return
    if PanelItems.Has(item) {
        action := PanelItems[item]
        action()
    } else {
        PanelTree.Modify(item, "Expand")   ; a category - open it
    }
}

ClosePanel() {
    if !Panel
        return
    try {
        Panel.GetPos(&x, &y)
        IniWrite(x, IniFile, "Panel", "X")
        IniWrite(y, IniFile, "Panel", "Y")
        IniWrite("0", IniFile, "Panel", "Open")
    }
    Panel.Hide()
}

ShowAbout() {
    MsgBox(AppName " " AppVersion "`n`n"
         . "Type rdmenu anywhere to open the menu.`n"
         . "Every item shows its hotstring in ( ).`n`n"
         . "Settings: " IniFile "`n`n"
         . AppUrl "`nMIT License", "About " AppName, "Iconi")
}

LogLine(msg) {
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " msg "`n", LogFile)
}

; ==============================================================================
; SETTINGS (WinQuickMenu.ini)
; ==============================================================================
LoadSettings() {
    global IdleEnabled, IdleLimitMin, WarnMin
    if !FileExist(IniFile) {
        try {
            IniWrite("90", IniFile, "IdleHibernate", "Minutes")
            IniWrite("2",  IniFile, "IdleHibernate", "WarnMinutes")
            IniWrite("TopRight", IniFile, "Menu", "Position")
        }
    }
    ; On/off is saved per computer, so turning it on here never turns it on
    ; for another PC that shares this folder through Dropbox/OneDrive.
    IdleEnabled := IniRead(IniFile, "IdleHibernate", "Enabled_" A_ComputerName, "0") = "1"
    try IdleLimitMin := Integer(IniRead(IniFile, "IdleHibernate", "Minutes", "90"))
    try WarnMin      := Integer(IniRead(IniFile, "IdleHibernate", "WarnMinutes", "2"))
    if (IdleLimitMin < 5)
        IdleLimitMin := 5
    if (WarnMin < 0 || WarnMin >= IdleLimitMin)
        WarnMin := 2
    global MenuPosition
    MenuPosition := IniRead(IniFile, "Menu", "Position", "TopRight")
    if !(MenuPosition ~= "i)^(TopRight|TopLeft|Mouse)$")
        MenuPosition := "TopRight"
}

; ==============================================================================
; IDLE HIBERNATE
; Hibernates after IdleLimitMin minutes with no keyboard/mouse input.
; Calls hibernate directly, so apps that hold Windows awake (remote-access
; tools, audio drivers, Electron apps) can't block it.
; ==============================================================================
OnPowerBroadcast(wParam, lParam, msg, hwnd) {
    global LastWake
    if (wParam = 0x7 || wParam = 0x12) {   ; PBT_APMRESUMESUSPEND / PBT_APMRESUMEAUTOMATIC
        LastWake := A_TickCount
        LogLine("Resumed")
    }
}

CheckIdle() {
    if !IdleEnabled
        return
    idleLimit := IdleLimitMin * 60 * 1000
    warnAt    := (IdleLimitMin - WarnMin) * 60 * 1000
    ; Idle = time since last input OR last wake, whichever is more recent
    idle := Min(A_TimeIdle, A_TickCount - LastWake)
    if (idle >= idleLimit) {
        ToolTip()
        LogLine("Idle hibernate after " Round(idle / 60000) " min")
        DoHibernate()
    } else if (WarnMin > 0 && idle >= warnAt) {
        ToolTip("Hibernating in about " WarnMin " min - move the mouse to cancel")
    } else {
        ToolTip()
    }
}

DoHibernate() {
    global LastWake
    ok := DllCall("PowrProf\SetSuspendState", "Int", 1, "Int", 0, "Int", 0)   ; 1 = hibernate
    LastWake := A_TickCount   ; runs after resume - restart the idle clock
    if !ok {
        LogLine("Hibernate failed")
        MsgBox("Windows refused to hibernate.`n`n"
             . "Hibernate may be turned off. To turn it on, open Terminal (Admin) and run:`n"
             . "    powercfg /hibernate on", AppName, "Icon! T20")
    }
}

ToggleIdle() {
    global IdleEnabled
    IdleEnabled := !IdleEnabled
    try IniWrite(IdleEnabled ? "1" : "0", IniFile, "IdleHibernate", "Enabled_" A_ComputerName)
    UpdateIdleCheck()
    ToolTip("Idle hibernate " (IdleEnabled ? "ON (" IdleLimitMin " min)" : "OFF"))
    SetTimer(() => ToolTip(), -2500)
    LogLine("Idle hibernate " (IdleEnabled ? "enabled" : "disabled"))
}

UpdateIdleCheck() {
    if IdleEnabled
        Menus["Power"].Check(IdleMenuLabel)
    else
        Menus["Power"].Uncheck(IdleMenuLabel)
}

ShowHibStat() {
    idle := Min(A_TimeIdle, A_TickCount - LastWake)
    MsgBox("Idle hibernate on " A_ComputerName ": " (IdleEnabled ? "ON" : "OFF") "`n"
         . "Hibernate after: " IdleLimitMin " min idle`n"
         . "Idle right now: " Round(idle / 60000, 1) " min`n`n"
         . "Settings: " IniFile "`n"
         . "Log: " LogFile, AppName, "Iconi T15")
}

; ==============================================================================
; COMMAND FUNCTIONS
; ==============================================================================
HibernateNow() {
    LogLine("Manual hibernate (hibnow)")
    Sleep 1000   ; let the hotstring finish typing/backspacing first
    DoHibernate()
}

SleepNow() {
    ; On PCs without sleep support (S3/modern standby), Windows may hibernate instead
    global LastWake
    Sleep 1000
    DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
    LastWake := A_TickCount
}

ShutdownTimer() {
    SafeRun("shutdown /s /t 3600")
    MsgBox("Shutdown scheduled in 1 hour.`nType sdcancel to cancel.", AppName, "Iconi T4")
}

ShutdownCancel() {
    SafeRun("shutdown /a")
    MsgBox("Scheduled shutdown cancelled.", AppName, "Iconi T3")
}

GodMode() {
    ; Creates the "God Mode" all-settings folder on the desktop, then opens it
    folder := A_Desktop "\GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
    if !DirExist(folder)
        DirCreate(folder)
    SafeRun(folder)
}

EmptyRecycleBin() {
    if MsgBox("Permanently delete everything in the Recycle Bin?", AppName, "YesNo Icon!") != "Yes"
        return
    try {
        FileRecycleEmpty()
        MsgBox("Recycle Bin emptied.", AppName, "Iconi T2")
    } catch {
        MsgBox("Recycle Bin is already empty or could not be emptied.", AppName, "Iconi T3")
    }
}

OpenTempFolder() {
    SafeRun(A_Temp)
}

ClearClipboard() {
    A_Clipboard := ""
    ToolTip("Clipboard cleared")
    SetTimer(() => ToolTip(), -1500)
}

ClipboardHistory() {
    Send "#v"
}
