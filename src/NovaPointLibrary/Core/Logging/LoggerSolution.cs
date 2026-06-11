using NovaPointLibrary.Commands.Utilities;
using NovaPointLibrary.Core.Execution;
using NovaPointLibrary.Core.SQLite;
using NovaPointLibrary.Solutions;
using Newtonsoft.Json;
using System.Diagnostics;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;


namespace NovaPointLibrary.Core.Logging
{
    internal class LoggerSolution : ILogger
    {
        public Action<LogInfo> UiAddLog {  get; init; }

        private readonly string _threadCode = "0";
        private int _childThreadCounter = 0;

        private static readonly SemaphoreSlim _semaphoreThreadLogger = new(1, 1);

        private readonly List<SolutionLog> _cachedKeyValues = new();
        private readonly List<SolutionLog> _cachedLogs = new();

        private readonly string _solutionName;
        internal readonly string _solutionFolderPath;
        internal readonly string _solutionFileName;

        private  Dictionary<Type, string>? _solutionReports = null;
        private readonly SqliteHandler _sql = SqliteHandler.GetCacheHandler();

        private readonly Stopwatch SW = new();

        private readonly string _txtPath;
        private readonly string _manifestPath;
        private readonly RunManifest _runManifest;
        static readonly ReaderWriterLockSlim txtRWL = new();


        // TO RETIRE
        private readonly string _csvPath;
        static readonly ReaderWriterLockSlim csvRWL = new();

        internal LoggerSolution(Action<LogInfo> uiAddLog, string solutionName, ISolutionParameters parameters)
        {
            UiAddLog = uiAddLog;
            _solutionName = solutionName;

            string userDocumentsFolder = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            _solutionFolderPath = Path.Combine(userDocumentsFolder, "NovaPoint", _solutionName, DateTime.UtcNow.ToString("yyMMddHHmmss"));
            Directory.CreateDirectory(_solutionFolderPath);

            _solutionFileName = _solutionName + "_" + DateTime.UtcNow.ToString("yyMMddHHmmss");

            _txtPath = Path.Combine(_solutionFolderPath, _solutionFileName + "_Logs.txt");
            _csvPath = Path.Combine(_solutionFolderPath, _solutionFileName + "_Report.csv");
            _manifestPath = Path.Combine(_solutionFolderPath, _solutionFileName + "_RunManifest.json");
            RunMode runMode = GetRunMode(parameters);
            _runManifest = new()
            {
                Version = VersionControl.GetVersion(),
                SolutionName = _solutionName,
                RunMode = runMode.ToString(),
                StartedUtc = DateTime.UtcNow,
                OutputFolder = _solutionFolderPath,
                TenantMutationIntent = GetTenantMutationIntent(runMode),
                SourceMutationIntent = GetSourceMutationIntent(runMode),
                Parameters = GetRedactedParameters(parameters),
                OutputFiles = new() { _txtPath, _csvPath, _manifestPath },
            };
            WriteRunManifest();

            Info(GetType().Name, $"Solution folder: {_solutionFolderPath}");

            SolutionLog logEntry = new("Info", _threadCode, GetType().Name, $"Version: v{VersionControl.GetVersion()}");
            WriteLog(logEntry);
            _cachedKeyValues.Add(logEntry);

            GetSolutionParameters(parameters);

            SW.Start();

            UI(GetType().Name, $"Solution has started, please wait to the end");
        }

        public async Task<ILogger> GetSubThreadLogger()
        {
            await _semaphoreThreadLogger.WaitAsync();
            try
            {
                LoggerThread childThread = new(this, _threadCode + "." + _childThreadCounter);
                _childThreadCounter++;
                return childThread;
            }
            finally
            {
                _semaphoreThreadLogger.Release();
            }
        }

        private void HistoryLog(SolutionLog log)
        {
            _cachedLogs.Add(log);

            while (_cachedLogs.Count > 20)
            {
                _cachedLogs.RemoveAt(0);
            }
        }

        public void Info(string classMethod, string log)
        {
            SolutionLog logEntry = new("Info", _threadCode, classMethod, log);
            HistoryLog(logEntry);

            WriteLog(logEntry);
        }

        public void Debug(string classMethod, string log)
        {
            SolutionLog logEntry = new("Debug", _threadCode, classMethod, log);
            HistoryLog(logEntry);

            WriteLog(logEntry);
        }

        public void UI(string classMethod, string log)
        {
            Info(classMethod, log);

            UiAddLog(LogInfo.TextNotification(log));
        }

        public void Progress(double progress)
        {
            if (progress < 0.01) { return; }

            if (progress > 99.99) { progress = 99.99; }

            TimeSpan timeSpan = TimeSpan.FromMilliseconds((SW.Elapsed.TotalMilliseconds * 100 / progress - SW.Elapsed.TotalMilliseconds));

            UiAddLog(LogInfo.ProgressUpdate(progress, timeSpan));
        }

        public void Error(string classMethod, string type, string URL, Exception ex)
        {

            List<SolutionLog> infoLogs = new()
            {
                new("Error", _threadCode, classMethod, $"Error processing {type} '{URL}'"),
                new("Error", _threadCode, classMethod, $"Exception: {ex.Message}"),
                new("Error", _threadCode, classMethod, $"Trace: {ex.StackTrace}"),
            };

            WriteLog(infoLogs);

            UiAddLog(LogInfo.ErrorNotification($"Error processing {type} '{URL}'."));
        }

        public void End(Exception? ex = null)
        {
            if (ex != null)
            {
                _runManifest.Status = ex is OperationCanceledException ? "Cancelled" : "Failed";
                Error(_solutionName, "Solution", _solutionName, ex);
                UiAddLog(LogInfo.ErrorNotification($"Exception: {ex.Message}"));
                UiAddLog(LogInfo.ErrorNotification($"StackTrace: {ex.StackTrace}"));
                UiAddLog(LogInfo.ErrorNotification($"COMPLETED: Solution has finished with errors!"));
            }
            else
            {
                _runManifest.Status = "Succeeded";
                UI(GetType().Name, $"COMPLETED: Solution has finished correctly!");
            }

            SW.Stop();
            _runManifest.EndedUtc = DateTime.UtcNow;
            WriteRunManifest();
            TimeSpan timeSpan = TimeSpan.FromMilliseconds((SW.Elapsed.TotalMilliseconds * 100 / 100 - SW.Elapsed.TotalMilliseconds));
            UiAddLog(LogInfo.ProgressUpdate(100, timeSpan));
        }


        private void WriteLog(List<SolutionLog> collRecord)
        {
            foreach (var record in collRecord)
            {
                WriteLog(record);
            }
        }

        public void WriteLog(SolutionLog log)
        {
            txtRWL.TryEnterWriteLock(3000);
            try
            {
                var fileStreamer = new FileStream(_txtPath, FileMode.Append, FileAccess.Write);
                using StreamWriter streamWriter = new(fileStreamer);

                streamWriter.WriteLine(log.GetLogEntry());
            }
            finally { txtRWL.ExitWriteLock(); }
        }

        private void WriteRunManifest()
        {
            string json = JsonConvert.SerializeObject(_runManifest, Formatting.Indented);
            File.WriteAllText(_manifestPath, json);
        }


        // RECORD PROPERTIES
        private void GetSolutionParameters(ISolutionParameters parameters)
        {
            LogProperty($"Solution parameters");
            LogProperty($"========== ========== ==========");

            GetProperties(parameters);

            LogProperty($"========== ========== ==========");
        }

        private void GetProperties(ISolutionParameters parameters)
        {
            Type type = parameters.GetType();
            PropertyInfo[] collPropertyInfo = type.GetProperties(BindingFlags.Public | BindingFlags.Instance);

            foreach (var propertyInfo in collPropertyInfo)
            {
                var oProperty = propertyInfo.GetValue(parameters);

                if (oProperty != null)
                {
                    if (typeof(ISolutionParameters).IsAssignableFrom(oProperty.GetType()))
                    {
                        GetProperties((ISolutionParameters)oProperty);
                    }
                    else
                    {
                        LogProperty($"{propertyInfo.Name}: {FormatParameterValue(propertyInfo, oProperty)}");
                    }
                }
            }

            parameters.ParametersCheck();
        }

        private void LogProperty(string property)
        {

            UI(GetType().Name, property);
        }

        private RunMode GetRunMode(ISolutionParameters parameters)
        {
            bool? reportMode = GetReportMode(parameters);

            if (reportMode == true)
            {
                return RunMode.Report;
            }

            if (reportMode == false)
            {
                return RunMode.Execute;
            }

            if (_solutionName.EndsWith("Report", StringComparison.OrdinalIgnoreCase) ||
                _solutionName.Equals("GetDirectoryGroup", StringComparison.OrdinalIgnoreCase))
            {
                return RunMode.Report;
            }

            return RunMode.Execute;
        }

        private static bool? GetReportMode(ISolutionParameters parameters)
        {
            PropertyInfo? reportModeProperty = parameters.GetType().GetProperty("ReportMode", BindingFlags.Public | BindingFlags.Instance);
            if (reportModeProperty != null && reportModeProperty.PropertyType == typeof(bool))
            {
                return (bool?)reportModeProperty.GetValue(parameters);
            }

            foreach (PropertyInfo propertyInfo in parameters.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                object? propertyValue = propertyInfo.GetValue(parameters);
                if (propertyValue is ISolutionParameters childParameters)
                {
                    bool? childReportMode = GetReportMode(childParameters);
                    if (childReportMode.HasValue)
                    {
                        return childReportMode;
                    }
                }
            }

            return null;
        }

        private static string GetTenantMutationIntent(RunMode runMode)
        {
            return runMode == RunMode.Execute ? "Possible" : "None";
        }

        private static string GetSourceMutationIntent(RunMode runMode)
        {
            return runMode == RunMode.Execute ? "Possible" : "None";
        }

        private static Dictionary<string, string> GetRedactedParameters(ISolutionParameters parameters)
        {
            Dictionary<string, string> values = new();
            AddRedactedParameters(values, parameters, parameters.GetType().Name);
            return values;
        }

        private static void AddRedactedParameters(Dictionary<string, string> values, ISolutionParameters parameters, string prefix)
        {
            foreach (PropertyInfo propertyInfo in parameters.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                object? propertyValue = propertyInfo.GetValue(parameters);
                string key = $"{prefix}.{propertyInfo.Name}";

                if (propertyValue is null)
                {
                    values[key] = "<null>";
                }
                else if (propertyValue is ISolutionParameters childParameters)
                {
                    AddRedactedParameters(values, childParameters, key);
                }
                else
                {
                    values[key] = FormatParameterValue(propertyInfo, propertyValue);
                }
            }
        }

        private static string FormatParameterValue(PropertyInfo propertyInfo, object value)
        {
            if (ShouldRedactParameter(propertyInfo.Name))
            {
                return "<redacted>";
            }

            return value switch
            {
                string text when ShouldRedactValue(text) => "<redacted>",
                string text => text,
                bool or byte or short or int or long or float or double or decimal or DateTime or DateTimeOffset or TimeSpan => value.ToString() ?? string.Empty,
                Enum => value.ToString() ?? string.Empty,
                _ => $"<{value.GetType().Name}>",
            };
        }

        private static bool ShouldRedactParameter(string propertyName)
        {
            string[] sensitiveNameParts =
            [
                "account",
                "credential",
                "email",
                "file",
                "folder",
                "group",
                "host",
                "item",
                "list",
                "login",
                "mail",
                "name",
                "path",
                "principal",
                "site",
                "tenant",
                "token",
                "url",
                "uri",
                "user",
            ];

            return sensitiveNameParts.Any(part => propertyName.Contains(part, StringComparison.OrdinalIgnoreCase));
        }

        private static bool ShouldRedactValue(string value)
        {
            return Uri.TryCreate(value, UriKind.Absolute, out _) ||
                   Regex.IsMatch(value, @"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}", RegexOptions.IgnoreCase);
        }


        // TO RETIRE
        public void DynamicCSV(dynamic o)
        {
            try
            {
                csvRWL.TryEnterWriteLock(3000);
                try
                {
                    StringBuilder sb = new();
                    using StreamWriter csv = new(new FileStream(_csvPath, FileMode.Append, FileAccess.Write));
                    {
                        var csvFileLenth = new System.IO.FileInfo(_csvPath).Length;
                        if (csvFileLenth == 0)
                        {
                            // https://learn.microsoft.com/en-us/dotnet/api/system.dynamic.expandoobject?redirectedfrom=MSDN&view=net-7.0#enumerating-and-deleting-members
                            foreach (var property in (IDictionary<String, Object>)o)
                            {
                                sb.Append($"\"{property.Key}\",");
                            }
                            if (sb.Length > 0) { sb.Length--; }
                            csv.WriteLine(sb.ToString());
                            sb.Clear();
                        }

                        foreach (var property in (IDictionary<String, Object>)o)
                        {
                            sb.Append($"\"{property.Value}\",");
                        }
                        if (sb.Length > 0) { sb.Length--; }

                        csv.WriteLine(sb.ToString());
                    }
                }
                finally { csvRWL.ExitWriteLock(); }
            }
            catch (Exception ex)
            {
                Error(GetType().Name, "Solution", _solutionName, ex);
            }
        }

    }

}
