# monitor-power.ps1 - switch the physical monitors off / on over DDC/CI (VCP code 0xD6). The GPU keeps rendering, so a
# stream keeps capturing, and mouse or keyboard input does NOT wake them (unlike Windows' own monitor-off).
#   -Query          current D6 value per monitor (1 = on, 4 = standby/off, 5 = off). "readable=False" = no DDC answer.
#   -Off            switch every monitor off: tries 4 first, reads back, falls back to 5 if the monitor ignored it
#   -On             wake every monitor (D6 = 1)
#   -Test [-Seconds 8]   off, wait, on. Run this ONCE with the owner watching before enabling MonitorsOff:
#                   every monitor must go dark AND come back by itself. One that stays dark needs its power button,
#                   and then MonitorsOff must stay disabled on this PC.
# Monitors differ: some honour 4, some only 5, some ignore D6 entirely, some stop answering DDC while off (the read then
# shows readable=False, which is fine as long as -On wakes them). DDC/CI must be enabled in the monitor's own menu.
param([switch]$Query, [switch]$Off, [switch]$On, [switch]$Test, [int]$Seconds = 8)
if ($Test) {
  & $PSCommandPath -Off
  "waiting $Seconds s: every monitor should be dark now"
  Start-Sleep -Seconds $Seconds
  & $PSCommandPath -On
  Start-Sleep -Seconds 4
  & $PSCommandPath -Query
  "TEST DONE: ask the owner whether every monitor went dark and came back on its own."
  return
}
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Ddc {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct PHYSICAL_MONITOR { public IntPtr hPhysicalMonitor; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string szPhysicalMonitorDescription; }
  public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, IntPtr lprc, IntPtr data);
  [DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc proc, IntPtr data);
  [DllImport("dxva2.dll")] public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, out uint count);
  [DllImport("dxva2.dll")] public static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint count, [Out] PHYSICAL_MONITOR[] arr);
  [DllImport("dxva2.dll")] public static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr h, byte code, out uint type, out uint current, out uint max);
  [DllImport("dxva2.dll")] public static extern bool SetVCPFeature(IntPtr h, byte code, uint value);
  [DllImport("dxva2.dll")] public static extern bool DestroyPhysicalMonitors(uint count, PHYSICAL_MONITOR[] arr);
  public static System.Collections.Generic.List<IntPtr> Monitors() {
    var l = new System.Collections.Generic.List<IntPtr>();
    EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (h, dc, rc, d) => { l.Add(h); return true; }, IntPtr.Zero);
    return l;
  }
}
"@
foreach ($hm in [Ddc]::Monitors()) {
  $n = [uint32]0; [Ddc]::GetNumberOfPhysicalMonitorsFromHMONITOR($hm, [ref]$n) | Out-Null
  if ($n -eq 0) { continue }
  $arr = New-Object 'Ddc+PHYSICAL_MONITOR[]' $n
  [Ddc]::GetPhysicalMonitorsFromHMONITOR($hm, $n, $arr) | Out-Null
  foreach ($pm in $arr) {
    $t = [uint32]0; $cur = [uint32]0; $max = [uint32]0
    $ok = [Ddc]::GetVCPFeatureAndVCPFeatureReply($pm.hPhysicalMonitor, 0xD6, [ref]$t, [ref]$cur, [ref]$max)
    if ($Query) { "{0}: D6 readable={1} current={2} max={3}" -f $pm.szPhysicalMonitorDescription, $ok, $cur, $max }
    if ($Off) {
      # try 4 first; a monitor that still reports "on" afterwards gets 5 (seen on an ASUS OLED: ignores 4, honours 5, wakes with 1)
      $r = [Ddc]::SetVCPFeature($pm.hPhysicalMonitor, 0xD6, 4); Start-Sleep -Milliseconds 800
      $t2 = [uint32]0; $c2 = [uint32]0; $m2 = [uint32]0
      $okr = [Ddc]::GetVCPFeatureAndVCPFeatureReply($pm.hPhysicalMonitor, 0xD6, [ref]$t2, [ref]$c2, [ref]$m2)
      if ($okr -and $c2 -eq 1) { $r = [Ddc]::SetVCPFeature($pm.hPhysicalMonitor, 0xD6, 5); "{0}: off (5) -> {1}" -f $pm.szPhysicalMonitorDescription, $r }
      else { "{0}: standby (4) -> {1}" -f $pm.szPhysicalMonitorDescription, $r }
    }
    if ($On)  { $r = [Ddc]::SetVCPFeature($pm.hPhysicalMonitor, 0xD6, 1); "{0}: on -> {1}" -f $pm.szPhysicalMonitorDescription, $r }
  }
  [Ddc]::DestroyPhysicalMonitors($n, $arr) | Out-Null
}
