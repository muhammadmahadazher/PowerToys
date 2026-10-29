param([Parameter(Mandatory)][string]$Assembly, [Parameter(Mandatory)][string]$ResultsName, [string]$ResultsDirectory = "$PSScriptRoot\..\logs")
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath "$PSScriptRoot\..\environment.ps1") { . "$PSScriptRoot\..\environment.ps1" }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = & $vswhere -latest -products '*' -property installationPath
$runner = Join-Path $vs 'Common7\IDE\Extensions\TestPlatform\vstest.console.exe'
$testAssembly = (Resolve-Path -LiteralPath $Assembly).Path
$resolvedResultsDirectory = (Resolve-Path -LiteralPath $ResultsDirectory).Path
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public static class RestrictedClipboardTestRunner
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct StartupInfo
    {
        public int Size;
        public string Reserved, Desktop, Title;
        public int X, Y, Width, Height, XCountChars, YCountChars, FillAttribute, Flags;
        public short ShowWindow, ReservedSize;
        public IntPtr ReservedBytes, Input, Output, Error;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct ProcessInfo
    {
        public IntPtr Process, Thread;
        public uint ProcessId, ThreadId;
    }

    public static int Run(string executable, string arguments, string directory)
    {
        IntPtr job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        ProcessInfo process = default;
        try
        {
            uint desktopRestriction = 0x40; // JOB_OBJECT_UILIMIT_DESKTOP
            if (!SetInformationJobObject(job, 4, ref desktopRestriction, 4))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            var startup = new StartupInfo { Size = Marshal.SizeOf<StartupInfo>() };
            var command = new StringBuilder("\"" + executable + "\" " + arguments);
            // Launch suspended so the restriction is in place before any tests execute.
            if (!CreateProcess(executable, command, IntPtr.Zero, IntPtr.Zero, false,
                0x08000004, IntPtr.Zero, directory, ref startup, out process))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            if (!AssignProcessToJobObject(job, process.Process))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            if (ResumeThread(process.Thread) == uint.MaxValue)
                throw new Win32Exception(Marshal.GetLastWin32Error());
            if (WaitForSingleObject(process.Process, 120000) != 0)
                throw new TimeoutException("Restricted test process did not complete.");
            if (!GetExitCodeProcess(process.Process, out uint code))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return unchecked((int)code);
        }
        finally
        {
            if (process.Process != IntPtr.Zero)
            {
                if (GetExitCodeProcess(process.Process, out uint code) && code == 259)
                    TerminateProcess(process.Process, 1);
                CloseHandle(process.Process);
            }
            if (process.Thread != IntPtr.Zero) CloseHandle(process.Thread);
            CloseHandle(job);
        }
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool SetInformationJobObject(IntPtr job, int informationClass, ref uint information, uint size);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool CreateProcess(string application, StringBuilder command, IntPtr processAttributes,
        IntPtr threadAttributes, bool inherit, uint flags, IntPtr environment, string directory,
        ref StartupInfo startup, out ProcessInfo process);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool GetExitCodeProcess(IntPtr process, out uint code);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool TerminateProcess(IntPtr process, uint code);
    [DllImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool CloseHandle(IntPtr handle);
}
'@
$arguments = '"{0}" /TestCaseFilter:FullyQualifiedName~ClipboardHelperTests "/Logger:trx;LogFileName={1}" "/ResultsDirectory:{2}"' -f $testAssembly,$ResultsName,$resolvedResultsDirectory
$testExitCode = [RestrictedClipboardTestRunner]::Run($runner,$arguments,(Split-Path -Parent $testAssembly))
Write-Output "Restricted runner exit code: $testExitCode"
exit $testExitCode
