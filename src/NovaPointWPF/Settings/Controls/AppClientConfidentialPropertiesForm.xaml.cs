using Microsoft.Win32;
using NovaPointLibrary.Core.Authentication;
using NovaPointLibrary.Core.Settings;
using System.Windows;
using System.Windows.Controls;


namespace NovaPointWPF.Settings.Controls
{
    public partial class AppClientConfidentialPropertiesForm : UserControl, IPropertiesForm
    {
        private readonly AppClientConfidentialProperties _properties;
        public IAppClientProperties Properties
        {
            get
            {
                if (PasswordBoxCertificatePassword.SecurePassword.Length > 0)
                {
                    System.Security.SecureString securePassword = PasswordBoxCertificatePassword.SecurePassword;
                    securePassword.MakeReadOnly();
                    _properties.Password = securePassword;
                }

                return _properties;
            }
        }
        private readonly AppClientPropertiesCoreForm _corePropertiesForm;

        internal AppClientConfidentialPropertiesForm(AppClientConfidentialProperties properties)
        {
            InitializeComponent();

            DataContext = properties;

            _properties = properties;
            SetStoredPasswordStatus();

            _corePropertiesForm = new(properties);
            FormPanel.Children.Insert(0, _corePropertiesForm);
        }

        public void EnableForm()
        {
            _corePropertiesForm.EnableForm();
            ButtonAppCertificate.IsEnabled = true;
            PasswordBoxCertificatePassword.IsEnabled = true;
        }

        public void DisableForm()
        {
            _corePropertiesForm.DisableForm();
            ButtonAppCertificate.IsEnabled = false;
            PasswordBoxCertificatePassword.Password = string.Empty;
            PasswordBoxCertificatePassword.IsEnabled = false;
            SetStoredPasswordStatus();
        }

        private void OpenCertificatePathClick(object sender, RoutedEventArgs e)
        {
            OpenFileDialog openFileDialog = new OpenFileDialog();
            if (openFileDialog.ShowDialog() == true)
                CertificatePathTextBlock.Text = openFileDialog.FileName;
        }

        private void SetStoredPasswordStatus()
        {
            StoredPasswordStatus.Text = _properties.CertificatePasswordSaved ? "Stored" : "Not stored";
        }

    }
}
