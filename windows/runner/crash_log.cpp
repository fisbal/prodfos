#include "crash_log.h"

#include <windows.h>
#include <dbghelp.h>
#include <shlobj.h>

#include <csignal>
#include <cstdio>
#include <string>

#pragma comment(lib, "dbghelp.lib")

namespace {

std::wstring g_dir;

LONG WINAPI OnCrash(EXCEPTION_POINTERS* info) {
  if (g_dir.empty()) return EXCEPTION_CONTINUE_SEARCH;
  const DWORD code = info && info->ExceptionRecord ? info->ExceptionRecord->ExceptionCode : 0;
  void* address = info && info->ExceptionRecord ? info->ExceptionRecord->ExceptionAddress : nullptr;

  wchar_t module[MAX_PATH] = L"?";
  HMODULE handle = nullptr;
  if (address &&
      GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                             GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         reinterpret_cast<LPCWSTR>(address), &handle)) {
    GetModuleFileNameW(handle, module, MAX_PATH);
  }

  SYSTEMTIME t;
  GetLocalTime(&t);
  MEMORYSTATUSEX mem{};
  mem.dwLength = sizeof(mem);
  GlobalMemoryStatusEx(&mem);

  FILE* f = nullptr;
  if (_wfopen_s(&f, (g_dir + L"\\crash.log").c_str(), L"a, ccs=UTF-8") == 0 && f) {
    fwprintf(f,
             L"%04d-%02d-%02d %02d:%02d:%02d  code 0x%08lX  at %p (offset 0x%llX)  in %s  memory used %lu%%\n",
             t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond, code, address,
             handle ? (unsigned long long)((char*)address - (char*)handle) : 0ULL, module,
             mem.dwMemoryLoad);
    fclose(f);
  }

  HANDLE dump = CreateFileW((g_dir + L"\\crash.dmp").c_str(), GENERIC_WRITE, 0, nullptr,
                            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (dump != INVALID_HANDLE_VALUE) {
    MINIDUMP_EXCEPTION_INFORMATION mei{};
    mei.ThreadId = GetCurrentThreadId();
    mei.ExceptionPointers = info;
    mei.ClientPointers = FALSE;
    MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), dump, MiniDumpNormal,
                      info ? &mei : nullptr, nullptr, nullptr);
    CloseHandle(dump);
  }
  return EXCEPTION_CONTINUE_SEARCH;
}

// abort() (std::terminate, out of memory in the engine) is not an exception.
void OnAbort(int) {
  if (!g_dir.empty()) {
    SYSTEMTIME t;
    GetLocalTime(&t);
    MEMORYSTATUSEX mem{};
    mem.dwLength = sizeof(mem);
    GlobalMemoryStatusEx(&mem);
    FILE* f = nullptr;
    if (_wfopen_s(&f, (g_dir + L"\\crash.log").c_str(), L"a, ccs=UTF-8") == 0 && f) {
      fwprintf(f, L"%04d-%02d-%02d %02d:%02d:%02d  abort  memory used %lu%%\n", t.wYear,
               t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond, mem.dwMemoryLoad);
      fclose(f);
    }
  }
}

}  // namespace

void InstallCrashLog() {
  wchar_t* local = nullptr;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &local)) && local) {
    g_dir = std::wstring(local) + L"\\ProDFOS";
    CreateDirectoryW(g_dir.c_str(), nullptr);
    g_dir += L"\\logs";
    CreateDirectoryW(g_dir.c_str(), nullptr);
    CoTaskMemFree(local);
  }
  SetUnhandledExceptionFilter(OnCrash);
  signal(SIGABRT, OnAbort);
}
