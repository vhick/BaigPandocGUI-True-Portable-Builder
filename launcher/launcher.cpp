// PandocGUI Portable Windows launcher. Community builder; MIT licensed.
// No installation, no system-wide changes, and conservative app-specific trace checks.
#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <winreg.h>
#include <filesystem>
#include <fstream>
#include <vector>
#include <string>
#include <set>
#include <algorithm>
#include <cwctype>
#include <cstdint>
#include <system_error>
namespace fs = std::filesystem;

static std::wstring getEnv(const wchar_t* key) {
    DWORD n = GetEnvironmentVariableW(key, nullptr, 0);
    if (!n) return {};
    std::wstring value(n, L'\0');
    DWORD written = GetEnvironmentVariableW(key, value.data(), n);
    if (!written || written >= n) return {};
    value.resize(written); return value;
}
static bool pathExists(const fs::path& p) { std::error_code ec; return fs::exists(p, ec); }
static std::wstring lower(std::wstring s) {
    std::transform(s.begin(), s.end(), s.begin(), [](wchar_t c) { return (wchar_t)towlower(c); });
    return s;
}
static bool appName(const std::wstring& name) {
    auto n = lower(name);
    return n == L"com.pandocgui.app" || n == L"baigpandocgui" ||
           n == L"baig-pandoc-gui" || n == L"baig pandoc gui" ||
           n.rfind(L"com.pandocgui.app-",0)==0 || n.rfind(L"baigpandocgui-",0)==0;
}
static std::wstring quote(const std::wstring& s) {
    std::wstring o=L"\""; size_t sl=0;
    for (auto c:s) {
        if (c==L'\\') ++sl;
        else if (c==L'"') { o.append(sl*2+1,L'\\');o+=L'"';sl=0; }
        else { o.append(sl,L'\\');sl=0;o+=c; }
    }
    o.append(sl*2,L'\\');o+=L'"';return o;
}
static void logLine(const fs::path& file, const std::wstring& content) {
    std::wofstream f(file, std::ios::app);
    if (f) f << content << L'\n';
}
static std::set<std::wstring> getHostTraces(const std::vector<fs::path>& dirs) {
    std::set<std::wstring> matches;
    for (const auto& base:dirs) {
        if (base.empty()) continue;
        std::error_code ec;
        for (const auto& entry:fs::directory_iterator(base,fs::directory_options::skip_permission_denied,ec)) {
            if (ec) break;
            if (appName(entry.path().filename().wstring())) matches.insert(entry.path().wstring());
        }
    }
    return matches;
}
static bool regExists(const wchar_t* key) {
    HKEY h=nullptr;
    auto result=RegOpenKeyExW(HKEY_CURRENT_USER,key,0,KEY_READ,&h);
    if(result==ERROR_SUCCESS)RegCloseKey(h);
    return result==ERROR_SUCCESS;
}
static void cleanupEmptyNewDir(const fs::path& dir,const fs::path& log) {
    // Never clean pre-existing paths, unknown names, symlinks/junctions, or any nonempty directory.
    if(!appName(dir.filename().wstring()))return;
    DWORD attr=GetFileAttributesW(dir.c_str());
    if(attr==INVALID_FILE_ATTRIBUTES || !(attr&FILE_ATTRIBUTE_DIRECTORY) || (attr&FILE_ATTRIBUTE_REPARSE_POINT))return;
    if(RemoveDirectoryW(dir.c_str()))logLine(log,L"REMOVED NEW EMPTY app-specific folder: "+dir.wstring());
    else logLine(log,L"PRESERVED NEW NONEMPTY/LOCKED folder (review manually): "+dir.wstring());
}
static void errorBox(const wchar_t* message) {
    MessageBoxW(nullptr,message,L"Baig Pandoc GUI Portable",MB_OK|MB_ICONERROR);
}
int WINAPI wWinMain(HINSTANCE,HINSTANCE,LPWSTR,int) {
    wchar_t module[32768]={};DWORD n=GetModuleFileNameW(nullptr,module,32768);
    if(!n || n>=32768){errorBox(L"Cannot resolve portable launcher location.");return 1;}
    fs::path root=fs::path(module).parent_path();
    uint64_t h=14695981039346656037ull;
    for(wchar_t c:root.wstring()){h^=(uint64_t)towlower(c);h*=1099511628211ull;}
    std::wstring mx=L"Local\\BaigPandocGUIPortable-"+std::to_wstring(h);
    HANDLE mutex=CreateMutexW(nullptr,FALSE,mx.c_str());
    if(mutex && GetLastError()==ERROR_ALREADY_EXISTS){
        errorBox(L"Baig Pandoc GUI Portable is already running from this folder.");
        CloseHandle(mutex);return 2;
    }
    fs::path data=root/L"Data", app=root/L"App", program=app/L"BaigPandocGUI.exe";
    fs::path pandoc=app/L"Tools"/L"Pandoc"/L"pandoc.exe";
    fs::path log=data/L"TraceGuard"/L"TraceGuard.log";
    if(!pathExists(program) || !pathExists(pandoc)){
        errorBox(L"App\\BaigPandocGUI.exe or App\\Tools\\Pandoc\\pandoc.exe is missing. Extract the entire ZIP.");
        if(mutex)CloseHandle(mutex);return 3;
    }
    // Snapshot the *original* user-profile paths before changing environment variables.
    const std::vector<fs::path> hostBases={getEnv(L"APPDATA"),getEnv(L"LOCALAPPDATA"),getEnv(L"PROGRAMDATA"),getEnv(L"TEMP")};
    const auto before=getHostTraces(hostBases);
    const wchar_t* keys[]={L"Software\\com.pandocgui.app",L"Software\\BaigPandocGUI",L"Software\\baig-pandoc-gui",L"Software\\Baig Pandoc GUI"};
    bool hadKey[4]={};for(int i=0;i<4;++i)hadKey[i]=regExists(keys[i]);
    std::error_code ec;
    const std::vector<fs::path> dirs={data/L"TraceGuard",data/L"Tauri",data/L"Home",data/L"Temp",data/L"Profile"/L"Roaming",data/L"Profile"/L"Local",data/L"Tools",data/L"PandocUserData"};
    for(const auto& dir:dirs){fs::create_directories(dir,ec);if(ec){errorBox(L"Cannot create the Data folders. Check drive write permissions.");if(mutex)CloseHandle(mutex);return 4;}}
    logLine(log,L"===== portable launch =====");
    logLine(log,L"Root: "+root.wstring());
    logLine(log,L"Original Windows user paths are not deleted or overwritten.");
    // Only this launcher and its descendants inherit these path changes.
    SetEnvironmentVariableW(L"BAIG_PANDOC_GUI_PORTABLE",L"1");
    SetEnvironmentVariableW(L"APPDATA",(data/L"Profile"/L"Roaming").c_str());
    SetEnvironmentVariableW(L"LOCALAPPDATA",(data/L"Profile"/L"Local").c_str());
    SetEnvironmentVariableW(L"HOME",(data/L"Home").c_str());
    SetEnvironmentVariableW(L"TEMP",(data/L"Temp").c_str());
    SetEnvironmentVariableW(L"TMP",(data/L"Temp").c_str());
    SetEnvironmentVariableW(L"PANDOC_DATA_DIR",(data/L"PandocUserData").c_str());
    SetEnvironmentVariableW(L"WEBVIEW2_USER_DATA_FOLDER",(data/L"Tauri"/L"WebView2").c_str());
    auto oldPath=getEnv(L"PATH");
    std::wstring newPath=(data/L"Tools").wstring()+L";"+(app/L"Tools"/L"Pandoc").wstring()+L";"+oldPath;
    SetEnvironmentVariableW(L"PATH",newPath.c_str());
    int argc=0;LPWSTR* argv=CommandLineToArgvW(GetCommandLineW(),&argc);
    std::wstring cmd=quote(program.wstring());
    for(int i=1;argv && i<argc;++i)cmd+=L" "+quote(argv[i]);
    if(argv)LocalFree(argv);
    std::vector<wchar_t> mutableCmd(cmd.begin(),cmd.end());mutableCmd.push_back(0);
    STARTUPINFOW si={};si.cb=sizeof(si);PROCESS_INFORMATION pi={};
    BOOL started=CreateProcessW(program.c_str(),mutableCmd.data(),nullptr,nullptr,FALSE,0,nullptr,app.c_str(),&si,&pi);
    if(!started){
        logLine(log,L"ERROR CreateProcessW failed with "+std::to_wstring(GetLastError()));
        errorBox(L"Baig Pandoc GUI could not start. Read Data\\TraceGuard\\TraceGuard.log.");
        if(mutex)CloseHandle(mutex);return 5;
    }
    CloseHandle(pi.hThread);
    WaitForSingleObject(pi.hProcess,INFINITE);
    DWORD result=0;GetExitCodeProcess(pi.hProcess,&result);CloseHandle(pi.hProcess);
    logLine(log,L"Baig Pandoc GUI exited; code="+std::to_wstring(result));
    auto after=getHostTraces(hostBases);
    for(const auto& dir:after){
        if(before.count(dir))continue;
        logLine(log,L"NEW HOST APP-SPECIFIC TRACE: "+dir);
        cleanupEmptyNewDir(dir,log);
    }
    for(int i=0;i<4;++i){
        if(!hadKey[i]&&regExists(keys[i]))logLine(log,std::wstring(L"NEW HKCU registry key (preserved for manual review): ")+keys[i]);
    }
    logLine(log,L"TraceGuard finished. Launcher did not intentionally remove any pre-existing host data; operating-system traces may remain.");
    if(mutex)CloseHandle(mutex);
    return (int)result;
}
