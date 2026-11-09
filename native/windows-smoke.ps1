param(
  [Parameter(Mandatory)][string]$Directory,
  [Parameter(Mandatory)][ValidateSet('x64', 'arm64')][string]$Architecture
)
$ErrorActionPreference = 'Stop'
$directoryPath = (Resolve-Path -LiteralPath $Directory).Path
$dllText = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes((Join-Path $directoryPath 'libmpv-2.dll')))
$features = [regex]::Match($dllText, 'List of enabled features: [^\x00\r\n]+').Value
foreach ($feature in @('gl', 'egl-angle')) {
  if ($features -notmatch "(?:^| )$feature(?: |$)") {
    throw "libmpv is missing required $feature rendering support."
  }
}
foreach ($file in Get-ChildItem -LiteralPath $directoryPath -Filter '*.dll') {
  $reader = [IO.BinaryReader]::new([IO.File]::OpenRead($file.FullName))
  try {
    if ($reader.ReadUInt16() -ne 0x5a4d) { throw "Not PE: $($file.Name)" }
    $reader.BaseStream.Position = 60
    $offset = $reader.ReadUInt32()
    $reader.BaseStream.Position = $offset
    if ($reader.ReadUInt32() -ne 0x4550) { throw "Not PE: $($file.Name)" }
    $expected = if ($Architecture -eq 'arm64') { 0xaa64 } else { 0x8664 }
    if ($reader.ReadUInt16() -ne $expected) { throw "Wrong DLL architecture: $($file.Name)" }
  } finally { $reader.Dispose() }
}
if ([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant() -cne $Architecture) {
  throw 'Native DLL loading must run under a matching PowerShell process.'
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NativeMediaSmoke {
  [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern IntPtr LoadLibraryEx(string file, IntPtr reserved, uint flags);
  [DllImport("kernel32", CharSet = CharSet.Ansi, SetLastError = true)]
  static extern IntPtr GetProcAddress(IntPtr module, string name);
  [DllImport("kernel32")] static extern bool FreeLibrary(IntPtr module);
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate ulong ClientVersion();
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr Create();
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Initialize(IntPtr context);
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void Destroy(IntPtr context);
  [StructLayout(LayoutKind.Sequential)] struct RenderParam { public int type; public IntPtr data; }
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int CreateRenderer(out IntPtr renderer, IntPtr context, [In] RenderParam[] parameters);
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void FreeRenderer(IntPtr renderer);
  public static void Check(string file, string symbol) {
    var module = LoadLibraryEx(file, IntPtr.Zero, 0x1100);
    if (module == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), file);
    try {
      if (GetProcAddress(module, symbol) == IntPtr.Zero) throw new Exception("Missing export: " + symbol);
      if (symbol == "mpv_client_api_version") {
        var version = Marshal.GetDelegateForFunctionPointer<ClientVersion>(GetProcAddress(module, symbol))();
        if (version >> 16 != 2) throw new Exception("Unexpected mpv client ABI");
        var context = Marshal.GetDelegateForFunctionPointer<Create>(GetProcAddress(module, "mpv_create"))();
        if (context == IntPtr.Zero) throw new Exception("mpv_create failed");
        try {
          if (Marshal.GetDelegateForFunctionPointer<Initialize>(GetProcAddress(module, "mpv_initialize"))(context) < 0)
            throw new Exception("mpv_initialize failed");
          var api = Marshal.StringToHGlobalAnsi("sw");
          try {
            IntPtr renderer;
            var parameters = new [] { new RenderParam { type = 1, data = api }, new RenderParam() };
            if (Marshal.GetDelegateForFunctionPointer<CreateRenderer>(GetProcAddress(module, "mpv_render_context_create"))(out renderer, context, parameters) < 0)
              throw new Exception("mpv software renderer initialization failed");
            Marshal.GetDelegateForFunctionPointer<FreeRenderer>(GetProcAddress(module, "mpv_render_context_free"))(renderer);
          } finally { Marshal.FreeHGlobal(api); }
        } finally {
          Marshal.GetDelegateForFunctionPointer<Destroy>(GetProcAddress(module, "mpv_terminate_destroy"))(context);
        }
      }
    } finally { FreeLibrary(module); }
  }
}
'@
foreach ($entry in @(@('libmpv-2.dll', 'mpv_client_api_version'), @('libEGL.dll', 'eglGetDisplay'), @('libGLESv2.dll', 'glGetString'))) {
  [NativeMediaSmoke]::Check((Join-Path $directoryPath $entry[0]), $entry[1])
}
Write-Output "Windows ${Architecture}: PE headers, DLL loading, OpenGL/ANGLE capabilities and mpv/software-renderer initialization passed."
