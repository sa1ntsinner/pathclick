param([switch]$Choose)
$ErrorActionPreference = 'Stop'
try {
    $target = $env:PATHCLICK_TARGET
    if (-not $target -or -not (Test-Path -LiteralPath $target)) { throw 'File not found' }
    if (-not $Choose -or (Get-Item -LiteralPath $target).PSIsContainer) {
        Start-Process -FilePath $target
        exit 0
    }
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PathclickOpenWith {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct OPENASINFO {
        [MarshalAs(UnmanagedType.LPWStr)] public string file;
        [MarshalAs(UnmanagedType.LPWStr)] public string className;
        public uint flags;
    }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = true)]
    public static extern int SHOpenWithDialog(IntPtr hwnd, ref OPENASINFO info);
}
'@
    $info = New-Object PathclickOpenWith+OPENASINFO
    $info.file = $target
    $info.flags = 4 # OAIF_EXEC: open after choosing, do not change the default association.
    $result = [PathclickOpenWith]::SHOpenWithDialog([IntPtr]::Zero, [ref]$info)
    if ($result -ne 0 -and $result -ne -2147023673) { throw ('Open with failed: {0:X8}' -f $result) }
} catch {
    [Console]::Error.WriteLine("pathclick: $($_.Exception.Message)")
    exit 1
}
