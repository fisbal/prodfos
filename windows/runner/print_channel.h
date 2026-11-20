#ifndef RUNNER_PRINT_CHANNEL_H_
#define RUNNER_PRINT_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// "prodfos/print": ProDFOS prints itself on Windows, with the printer's own
// settings (DEVMODE) that it keeps per printer.
//   preferences {printer, devmode?}            -> devmode bytes, or null if cancelled
//   begin {printer, devmode?, name, pageWidth, pageHeight (points)} -> {dpiX, dpiY}
//   page {pixels (RGBA), width, height, pageWidth, pageHeight (points)}
//   end / abort
void RegisterPrintChannel(flutter::BinaryMessenger* messenger, HWND window);

#endif  // RUNNER_PRINT_CHANNEL_H_
