#include "print_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <winspool.h>

#include <algorithm>
#include <cmath>
#include <memory>
#include <string>
#include <vector>

#pragma comment(lib, "winspool.lib")

namespace {

HWND g_window = nullptr;
HDC g_dc = nullptr;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

std::wstring Wide(const std::string& s) {
  if (s.empty()) return L"";
  int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
  std::wstring w(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), &w[0], n);
  return w;
}

const flutter::EncodableValue* Arg(const flutter::EncodableMap& m, const char* key) {
  auto it = m.find(flutter::EncodableValue(key));
  if (it == m.end() || it->second.IsNull()) return nullptr;
  return &it->second;
}

std::string StrArg(const flutter::EncodableMap& m, const char* key) {
  auto v = Arg(m, key);
  if (v && std::holds_alternative<std::string>(*v)) return std::get<std::string>(*v);
  return "";
}

double NumArg(const flutter::EncodableMap& m, const char* key, double def) {
  auto v = Arg(m, key);
  if (!v) return def;
  if (std::holds_alternative<double>(*v)) return std::get<double>(*v);
  if (std::holds_alternative<int32_t>(*v)) return std::get<int32_t>(*v);
  if (std::holds_alternative<int64_t>(*v)) return (double)std::get<int64_t>(*v);
  return def;
}

const std::vector<uint8_t>* BytesArg(const flutter::EncodableMap& m, const char* key) {
  auto v = Arg(m, key);
  if (v && std::holds_alternative<std::vector<uint8_t>>(*v)) return &std::get<std::vector<uint8_t>>(*v);
  return nullptr;
}

// The printer's DEVMODE: the saved one if it still fits this driver, else the
// driver's current defaults (Windows "Printing preferences").
std::vector<uint8_t> LoadDevMode(HANDLE printer, const std::wstring& name,
                                 const std::vector<uint8_t>* saved, bool prompt) {
  LONG size = DocumentPropertiesW(g_window, printer, const_cast<LPWSTR>(name.c_str()),
                                  nullptr, nullptr, 0);
  if (size <= 0) return {};
  std::vector<uint8_t> out(size);
  DEVMODEW* in = nullptr;
  std::vector<uint8_t> inCopy;
  if (saved && saved->size() >= sizeof(DEVMODEW)) {
    inCopy = *saved;
    auto dm = reinterpret_cast<DEVMODEW*>(inCopy.data());
    if ((size_t)dm->dmSize + dm->dmDriverExtra == inCopy.size() &&
        _wcsnicmp(dm->dmDeviceName, name.c_str(), CCHDEVICENAME - 1) == 0) {
      in = dm;
    }
  }
  DWORD mode = DM_OUT_BUFFER | (in ? DM_IN_BUFFER : 0) | (prompt ? DM_IN_PROMPT : 0);
  LONG r = DocumentPropertiesW(g_window, printer, const_cast<LPWSTR>(name.c_str()),
                               reinterpret_cast<DEVMODEW*>(out.data()), in, mode);
  if (prompt && r != IDOK) return {};
  if (!prompt && r < 0) return {};
  return out;
}

// Standard paper matching the PDF page, so the driver does not fall back to its
// photo or default size.
short PaperFor(double wPt, double hPt) {
  double a = std::min(wPt, hPt), b = std::max(wPt, hPt);
  auto isSize = [&](double x, double y) { return std::fabs(a - x) < 6 && std::fabs(b - y) < 6; };
  if (isSize(612, 792)) return DMPAPER_LETTER;
  if (isSize(612, 1008)) return DMPAPER_LEGAL;
  if (isSize(595.3, 841.9)) return DMPAPER_A4;
  if (isSize(419.5, 595.3)) return DMPAPER_A5;
  return 0;
}

void Finish() {
  if (g_dc) {
    DeleteDC(g_dc);
    g_dc = nullptr;
  }
}

void HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());

  if (method == "end") {
    if (g_dc) EndDoc(g_dc);
    Finish();
    result->Success();
    return;
  }
  if (method == "abort") {
    if (g_dc) AbortDoc(g_dc);
    Finish();
    result->Success();
    return;
  }
  if (!args) {
    result->Error("args", "Missing arguments");
    return;
  }

  if (method == "preferences" || method == "begin") {
    std::wstring name = Wide(StrArg(*args, "printer"));
    HANDLE printer = nullptr;
    if (name.empty() || !OpenPrinterW(const_cast<LPWSTR>(name.c_str()), &printer, nullptr)) {
      result->Error("printer", "Printer not found");
      return;
    }
    const bool prompt = method == "preferences";
    std::vector<uint8_t> dm = LoadDevMode(printer, name, BytesArg(*args, "devmode"), prompt);
    ClosePrinter(printer);

    if (prompt) {
      if (dm.empty()) result->Success();  // cancelled
      else result->Success(flutter::EncodableValue(dm));
      return;
    }

    DEVMODEW* devmode = dm.empty() ? nullptr : reinterpret_cast<DEVMODEW*>(dm.data());
    if (devmode && !BytesArg(*args, "devmode")) {
      // Nothing saved yet: match the paper to the document.
      short paper = PaperFor(NumArg(*args, "pageWidth", 612), NumArg(*args, "pageHeight", 792));
      if (paper) {
        devmode->dmPaperSize = paper;
        devmode->dmFields |= DM_PAPERSIZE;
        devmode->dmFields &= ~(DM_PAPERLENGTH | DM_PAPERWIDTH);
      }
    }
    if (devmode) {
      // ProDFOS repeats the pages itself for copies.
      devmode->dmCopies = 1;
      devmode->dmFields |= DM_COPIES;
    }

    Finish();
    g_dc = CreateDCW(L"WINSPOOL", name.c_str(), nullptr, devmode);
    if (!g_dc) {
      result->Error("printer", "Cannot open the printer");
      return;
    }
    std::wstring doc = Wide(StrArg(*args, "name"));
    if (doc.empty()) doc = L"ProDFOS";
    DOCINFOW info{};
    info.cbSize = sizeof(info);
    info.lpszDocName = doc.c_str();
    if (StartDocW(g_dc, &info) <= 0) {
      Finish();
      result->Error("printer", "The printer refused the document");
      return;
    }
    flutter::EncodableMap out;
    out[flutter::EncodableValue("dpiX")] = flutter::EncodableValue(GetDeviceCaps(g_dc, LOGPIXELSX));
    out[flutter::EncodableValue("dpiY")] = flutter::EncodableValue(GetDeviceCaps(g_dc, LOGPIXELSY));
    result->Success(flutter::EncodableValue(out));
    return;
  }

  if (method == "page") {
    const auto* pixels = BytesArg(*args, "pixels");
    int w = (int)NumArg(*args, "width", 0), h = (int)NumArg(*args, "height", 0);
    if (!g_dc || !pixels || w <= 0 || h <= 0 || pixels->size() < (size_t)w * h * 4) {
      result->Error("page", "Bad page");
      return;
    }
    // RGBA -> BGRA for GDI, white under transparent parts.
    std::vector<uint8_t> bgra(*pixels);
    for (size_t i = 0; i + 3 < bgra.size(); i += 4) {
      uint8_t r = bgra[i], g = bgra[i + 1], b = bgra[i + 2], a = bgra[i + 3];
      bgra[i] = (uint8_t)((b * a + 255 * (255 - a)) / 255);
      bgra[i + 1] = (uint8_t)((g * a + 255 * (255 - a)) / 255);
      bgra[i + 2] = (uint8_t)((r * a + 255 * (255 - a)) / 255);
      bgra[i + 3] = 255;
    }

    const double dpiX = GetDeviceCaps(g_dc, LOGPIXELSX), dpiY = GetDeviceCaps(g_dc, LOGPIXELSY);
    const double physW = GetDeviceCaps(g_dc, PHYSICALWIDTH), physH = GetDeviceCaps(g_dc, PHYSICALHEIGHT);
    const double offX = GetDeviceCaps(g_dc, PHYSICALOFFSETX), offY = GetDeviceCaps(g_dc, PHYSICALOFFSETY);
    // Actual size (100 %), shrunk only if the page is bigger than the paper, centred.
    double destW = NumArg(*args, "pageWidth", 612) / 72.0 * dpiX;
    double destH = NumArg(*args, "pageHeight", 792) / 72.0 * dpiY;
    double fit = std::min({1.0, physW / destW, physH / destH});
    destW *= fit;
    destH *= fit;
    int x = (int)std::lround((physW - destW) / 2 - offX);
    int y = (int)std::lround((physH - destH) / 2 - offY);

    BITMAPINFO bmi{};
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = w;
    bmi.bmiHeader.biHeight = -h;  // top-down
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    if (StartPage(g_dc) <= 0) {
      result->Error("page", "The printer refused the page");
      return;
    }
    SetStretchBltMode(g_dc, HALFTONE);
    SetBrushOrgEx(g_dc, 0, 0, nullptr);
    StretchDIBits(g_dc, x, y, (int)std::lround(destW), (int)std::lround(destH), 0, 0, w, h,
                  bgra.data(), &bmi, DIB_RGB_COLORS, SRCCOPY);
    EndPage(g_dc);
    result->Success();
    return;
  }

  result->NotImplemented();
}

}  // namespace

void RegisterPrintChannel(flutter::BinaryMessenger* messenger, HWND window) {
  g_window = window;
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "prodfos/print", &flutter::StandardMethodCodec::GetInstance());
  g_channel->SetMethodCallHandler(HandleCall);
}
