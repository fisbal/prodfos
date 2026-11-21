#ifndef RUNNER_CRASH_LOG_H_
#define RUNNER_CRASH_LOG_H_

// If ProDFOS stops because of a native error, writes what happened (error code,
// module) to %LOCALAPPDATA%\ProDFOS\logs\crash.log and a small crash.dmp, so the
// cause can be found and fixed.
void InstallCrashLog();

#endif  // RUNNER_CRASH_LOG_H_
