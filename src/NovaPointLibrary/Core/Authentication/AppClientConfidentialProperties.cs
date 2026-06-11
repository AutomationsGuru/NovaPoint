using Newtonsoft.Json;
using System.Security.Cryptography.X509Certificates;


namespace NovaPointLibrary.Core.Authentication
{
    public class AppClientConfidentialProperties : IAppClientProperties
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public string ClientTitle { get; set; } = "Name of App-Only";
        public Guid TenantId { get; set; } = Guid.Empty;
        public Guid ClientId { get; set; } = Guid.Empty;
        public string CertificatePath { get; set; } = string.Empty;
        public bool CertificatePasswordSaved { get; set; } = false;

        [JsonIgnore]
        public System.Security.SecureString? Password { get; set; } = null;

        internal X509Certificate2 Certificate
        {
            get
            {
                System.Security.SecureString? password = Password ?? AppClientCertificatePasswordStore.Load(Id);
                return new X509Certificate2(CertificatePath, password);
            }
        }

        public AppClientConfidentialProperties() { }

        public AppClientConfidentialProperties Clone()
        {
            AppClientConfidentialProperties clone = (AppClientConfidentialProperties)this.MemberwiseClone();
            clone.Password = null;
            return clone;
        }

        public void ValidateProperties()
        {
            if (TenantId == Guid.Empty)
            {
                throw new Exception("Incorrect Tenant ID");
            }
            if (ClientId == Guid.Empty)
            {
                throw new Exception("Incorrect Client ID");
            }
            if (string.IsNullOrWhiteSpace(CertificatePath))
            {
                throw new Exception("Missing certificate path");
            }
            if (!File.Exists(CertificatePath))
            {
                throw new Exception("Certificate no found on path");
            }
            try
            {
                using X509Certificate2 certificate = Certificate;
            }
            catch
            {
                throw new Exception("Certificate could not be opened. Confirm the certificate path and password.");
            }
        }
    }
}
