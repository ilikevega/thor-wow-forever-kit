# audio-default.ps1 - read or set the Windows default playback device. No modules: Core Audio / PolicyConfig COM.
#   -Get            prints the default playback endpoint id
#   -List           prints ACTIVE playback endpoints: id <tab> name
#   -ListAll        prints every playback endpoint, also disabled and unplugged ones: state <tab> id <tab> name
#                   (state 1 = active, 2 = disabled, 4 = not present, 8 = unplugged)
#   -Set "<id>"     makes that endpoint the default for console, multimedia and communications
#   -Enable "<id>"  re-enables a disabled endpoint (same as "Show disabled devices" > Enable in the Sound panel)
param([switch]$Get, [switch]$List, [switch]$ListAll, [string]$Set, [string]$Enable)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
namespace AudioDef {
  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] public class MMDeviceEnumeratorCom {}
  [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
  }
  [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IMMDeviceCollection { int GetCount(out int count); int Item(int index, out IMMDevice device); }
  [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IMMDevice {
    int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    int OpenPropertyStore(int access, out IPropertyStore properties);
    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    int GetState(out int state);
  }
  [StructLayout(LayoutKind.Sequential, Pack = 4)] public struct PROPERTYKEY { public Guid fmtid; public int pid; }
  [StructLayout(LayoutKind.Sequential)] public struct PROPVARIANT { public short vt; public short r1; public short r2; public short r3; public IntPtr p; public IntPtr p2; }
  [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IPropertyStore { int GetCount(out int c); int GetAt(int i, out PROPERTYKEY k); int GetValue(ref PROPERTYKEY k, out PROPVARIANT v); }
  [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")] public class PolicyConfigClientCom {}
  [ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IPolicyConfig {
    int GetMixFormat(string id, IntPtr f); int GetDeviceFormat(string id, int d, IntPtr f); int ResetDeviceFormat(string id);
    int SetDeviceFormat(string id, IntPtr a, IntPtr b); int GetProcessingPeriod(string id, int d, IntPtr a, IntPtr b);
    int SetProcessingPeriod(string id, IntPtr p); int GetShareMode(string id, IntPtr m); int SetShareMode(string id, IntPtr m);
    int GetPropertyValue(string id, IntPtr k, IntPtr v); int SetPropertyValue(string id, IntPtr k, IntPtr v);
    int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role); int SetEndpointVisibility(string id, int v);
  }
  public static class Api {
    public static string DefaultId() { var e = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom(); IMMDevice d; e.GetDefaultAudioEndpoint(0, 1, out d); string id; d.GetId(out id); return id; }
    public static string Name(IMMDevice d) {
      IPropertyStore ps; d.OpenPropertyStore(0, out ps);
      var key = new PROPERTYKEY { fmtid = new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"), pid = 14 };
      PROPVARIANT v; ps.GetValue(ref key, out v);
      return v.vt == 31 ? Marshal.PtrToStringUni(v.p) : "?";
    }
    public static string[] ListByState(int mask, bool withState) {
      var e = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom(); IMMDeviceCollection c; e.EnumAudioEndpoints(0, mask, out c);
      int n; c.GetCount(out n); var res = new string[n];
      for (int i = 0; i < n; i++) {
        IMMDevice d; c.Item(i, out d); string id; d.GetId(out id); int st; d.GetState(out st);
        string nm; try { nm = Name(d); } catch { nm = "?"; }
        res[i] = (withState ? st + "\t" : "") + id + "\t" + nm;
      }
      return res;
    }
    public static int EnableEndpoint(string id) { var p = (IPolicyConfig)new PolicyConfigClientCom(); return p.SetEndpointVisibility(id, 1); }
    public static int SetDefault(string id) {
      var p = (IPolicyConfig)new PolicyConfigClientCom(); int r = 0;
      foreach (int role in new int[] { 0, 1, 2 }) { int hr = p.SetDefaultEndpoint(id, role); if (hr != 0) r = hr; }
      return r;
    }
  }
}
"@
if ($Get)  { [AudioDef.Api]::DefaultId() }
if ($List) { [AudioDef.Api]::ListByState(1, $false) | ForEach-Object { $_ } }
if ($ListAll) { [AudioDef.Api]::ListByState(15, $true) | ForEach-Object { $_ } }
if ($Enable) { $hr = [AudioDef.Api]::EnableEndpoint($Enable); if ($hr -eq 0) { "enabled: $Enable" } else { "enable FAILED hr=0x{0:X8}" -f $hr; exit 1 } }
if ($Set)  { $hr = [AudioDef.Api]::SetDefault($Set); if ($hr -eq 0) { "default set: $Set" } else { "FAILED hr=0x{0:X8}" -f $hr; exit 1 } }
