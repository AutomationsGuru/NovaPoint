namespace NovaPointLibrary.Core.Logging
{
    internal class RunManifest
    {
        public string ApplicationName { get; set; } = "AutomationsGuru SPO Toolkit (NovaPoint-derived)";
        public string Version { get; set; } = string.Empty;
        public string SolutionName { get; set; } = string.Empty;
        public string RunMode { get; set; } = string.Empty;
        public string Status { get; set; } = "Running";
        public DateTime StartedUtc { get; set; }
        public DateTime? EndedUtc { get; set; }
        public string OutputFolder { get; set; } = string.Empty;
        public string TenantMutationIntent { get; set; } = "None";
        public string SourceMutationIntent { get; set; } = "None";
        public string ParameterRedactionPolicy { get; set; } = "Sensitive parameter values are redacted by property name.";
        public Dictionary<string, string> Parameters { get; set; } = [];
        public List<string> OutputFiles { get; set; } = [];
    }
}
