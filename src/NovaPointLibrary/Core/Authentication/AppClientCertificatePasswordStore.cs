using NovaPointLibrary.Commands.Utilities;
using System.Runtime.InteropServices;
using System.Security;
using System.Security.Cryptography;
using System.Text;

#pragma warning disable CA1416

namespace NovaPointLibrary.Core.Authentication
{
    internal static class AppClientCertificatePasswordStore
    {
        private static readonly byte[] s_entropy = Encoding.UTF8.GetBytes("AutomationsGuru.NovaPoint.AppOnlyCertificatePassword.v1");

        internal static bool HasPassword(Guid clientId)
        {
            return File.Exists(GetPasswordPath(clientId));
        }

        internal static SecureString? Load(Guid clientId)
        {
            string passwordPath = GetPasswordPath(clientId);
            if (!File.Exists(passwordPath))
            {
                return null;
            }

            AssertWindowsDpapiAvailable();

            byte[] encryptedBytes = File.ReadAllBytes(passwordPath);
            byte[] passwordBytes = ProtectedData.Unprotect(encryptedBytes, s_entropy, DataProtectionScope.CurrentUser);
            try
            {
                return ToSecureString(Encoding.UTF8.GetString(passwordBytes));
            }
            finally
            {
                Array.Clear(passwordBytes);
            }
        }

        internal static void Save(Guid clientId, SecureString password)
        {
            if (password.Length == 0)
            {
                return;
            }

            Directory.CreateDirectory(GetPasswordFolder());

            AssertWindowsDpapiAvailable();

            string passwordText = SecureStringToString(password);
            byte[] passwordBytes = Encoding.UTF8.GetBytes(passwordText);
            try
            {
                byte[] encryptedBytes = ProtectedData.Protect(passwordBytes, s_entropy, DataProtectionScope.CurrentUser);
                File.WriteAllBytes(GetPasswordPath(clientId), encryptedBytes);
            }
            finally
            {
                Array.Clear(passwordBytes);
            }
        }

        internal static void Delete(Guid clientId)
        {
            string passwordPath = GetPasswordPath(clientId);
            if (File.Exists(passwordPath))
            {
                File.Delete(passwordPath);
            }
        }

        private static string GetPasswordPath(Guid clientId)
        {
            return Path.Combine(GetPasswordFolder(), $"{clientId:N}.bin");
        }

        private static string GetPasswordFolder()
        {
            string localAppFolder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "NovaPoint",
                VersionControl.GetVersion());

            return Path.Combine(localAppFolder, "secrets", "certificate-passwords");
        }

        private static void AssertWindowsDpapiAvailable()
        {
            if (!OperatingSystem.IsWindows())
            {
                throw new PlatformNotSupportedException("Certificate password storage uses Windows DPAPI.");
            }
        }

        private static string SecureStringToString(SecureString secureString)
        {
            IntPtr valuePtr = IntPtr.Zero;
            try
            {
                valuePtr = Marshal.SecureStringToBSTR(secureString);
                return Marshal.PtrToStringBSTR(valuePtr) ?? string.Empty;
            }
            finally
            {
                if (valuePtr != IntPtr.Zero)
                {
                    Marshal.ZeroFreeBSTR(valuePtr);
                }
            }
        }

        private static SecureString ToSecureString(string value)
        {
            SecureString secureString = new();
            foreach (char c in value)
            {
                secureString.AppendChar(c);
            }

            secureString.MakeReadOnly();
            return secureString;
        }
    }
}

#pragma warning restore CA1416
