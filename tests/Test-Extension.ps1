[CmdletBinding()]
param([string]$VlcDirectory = 'C:\Program Files\VideoLAN\VLC')
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VlcLuaTest {
    [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern bool SetDllDirectory(string path);
    [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr LoadLibrary(string path);
    [DllImport("kernel32", CharSet=CharSet.Ansi)]
    static extern IntPtr GetProcAddress(IntPtr module, string name);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr NewState();
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void StateAction(IntPtr state);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int LoadString(IntPtr state, byte[] text);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int PCall(IntPtr state, int args, int results, int handler);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr LuaString(IntPtr state, int index, out UIntPtr length);
    static T Function<T>(IntPtr module, string name) {
        return (T)(object)Marshal.GetDelegateForFunctionPointer(GetProcAddress(module, name), typeof(T));
    }
    public static string Run(string directory, string script) {
        SetDllDirectory(directory);
        IntPtr module = LoadLibrary(directory + @"\plugins\lua\liblua_plugin.dll");
        if (module == IntPtr.Zero) throw new Exception("Cannot load VLC Lua DLL; match PowerShell and VLC bitness.");
        IntPtr state = Function<NewState>(module,"luaL_newstate")();
        try {
            Function<StateAction>(module,"luaL_openlibs")(state);
            int code = Function<LoadString>(module,"luaL_loadstring")(state, System.Text.Encoding.UTF8.GetBytes(script + "\0"));
            if (code == 0) code = Function<PCall>(module,"lua_pcall")(state,0,1,0);
            UIntPtr size;
            IntPtr result = Function<LuaString>(module,"lua_tolstring")(state,-1,out size);
            byte[] bytes = new byte[(int)size.ToUInt64()];
            Marshal.Copy(result,bytes,0,bytes.Length);
            string text = System.Text.Encoding.UTF8.GetString(bytes);
            if (code != 0) throw new Exception(text);
            return text;
        } finally {
            Function<StateAction>(module,"lua_close")(state);
            SetDllDirectory(null);
        }
    }
}
'@
$source = (Resolve-Path (Join-Path $PSScriptRoot '../src/vlc-deleter.lua')).Path.Replace('\','/')
$test = (Join-Path $PSScriptRoot 'test-extension.lua').Replace('\','/')
$testRoot = Join-Path $PSScriptRoot ('tmp/integration-' + [Guid]::NewGuid().ToString('N'))
& (Join-Path $PSScriptRoot '../Install.ps1') -VlcDataDirectory $testRoot | Out-Null
$name = 'video & %PATH% [1] ' + [char]::ConvertFromUtf32(0x1f3ac) + '.avi'
$file = Join-Path $testRoot $name
[IO.File]::WriteAllText($file, 'Disposable extension-to-helper integration fixture')
$uri = ([Uri]$file).AbsoluteUri
$dataPath = $testRoot.Replace('\','/')
Write-Output ([VlcLuaTest]::Run($VlcDirectory, "vlc={}; test_source=[[$source]]; test_data=[[$dataPath]]; test_file_uri=[[$uri]]; return dofile([[$test]])"))
if (Test-Path -LiteralPath $file) { throw 'Integration fixture was not deleted.' }
