using NovaPointLibrary.Solutions;
using System;
using System.Collections.Generic;
using System.Reflection;
using System.Threading;
using System.Windows;
using System.Windows.Controls;


namespace NovaPointWPF.Pages.Solutions
{
    public partial class SolutionPreparationPage : Page
    {
        static ReaderWriterLock rwl = new ReaderWriterLock();
        private readonly ISolutionForm _solutionForm;
        private const string ExecuteApprovalPhrase = "APPROVE EXECUTE";

        private static readonly HashSet<string> MutationCapableSolutionCodes = new(StringComparer.Ordinal)
        {
            "CheckInFileAuto",
            "ClearRecycleBinAuto",
            "CopyDuplicateFileAuto",
            "IdMismatchTrouble",
            "RemoveFileVersionAuto",
            "RemovePHLItemAuto",
            "RemoveSharingLinksAuto",
            "RemoveSiteAuto",
            "RemoveSiteUserAuto",
            "RestorePHLItemAuto",
            "RestoreRecycleBinAuto",
            "SetSiteCollectionAdminAuto",
            "SetVersioningLimitAuto",
        };

        public SolutionPreparationPage(ISolutionForm solutionForm)
        {
            InitializeComponent();

            DataContext = this;

            SolutionHeader.SolutionTitle = solutionForm.SolutionName;
            SolutionHeader.SolutionCode = solutionForm.SolutionCode;
            SolutionHeader.SolutionDocs = solutionForm.SolutionDocs;

            SolutionFormFrame.Content = solutionForm;

            _solutionForm = solutionForm;
        }

        private void Back_Click(object sender, RoutedEventArgs e)
        {
            MainWindow? mainWindow = Application.Current.MainWindow as MainWindow;

            if (mainWindow is not null) { Application.Current.MainWindow.Content = mainWindow.MainPage; }
        }

        private async void RunButton_ClickAsync(object sender, RoutedEventArgs e)
        {
            ISolutionParameters parameters;
            try
            {
                parameters = _solutionForm.GetParameters();
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    $"Solution parameters are not valid. {ex.Message}",
                    "AutomationsGuru SPO Toolkit",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);
                return;
            }

            if (RequiresExecutionApproval(parameters) && !ShowExecutionApprovalDialog())
            {
                return;
            }

            BackButton.IsEnabled = false;
            RunButton.IsEnabled = false;
            StackPanelForm.IsEnabled = false;


            try
            {
                SolutionHandler handler = new(_solutionForm.SolutionCreate, parameters, AppSelector.GetClient());

                SolutionProgressView sViewer = new(handler);
                SolutionProgressViewFrame.Content = sViewer;

                await sViewer.RunSolutionAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    $"Solution failed to start. {ex.Message}",
                    "AutomationsGuru SPO Toolkit",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);
            }

            BackButton.IsEnabled = true;
            RunButton.IsEnabled = true;
            StackPanelForm.IsEnabled = true;
        }

        private bool RequiresExecutionApproval(ISolutionParameters parameters)
        {
            if (!MutationCapableSolutionCodes.Contains(_solutionForm.SolutionCode))
            {
                return false;
            }

            bool? reportMode = GetReportMode(parameters);
            return reportMode != true;
        }

        private static bool? GetReportMode(ISolutionParameters parameters)
        {
            PropertyInfo? reportModeProperty = parameters.GetType().GetProperty("ReportMode", BindingFlags.Public | BindingFlags.Instance);
            if (reportModeProperty == null || reportModeProperty.PropertyType != typeof(bool))
            {
                return null;
            }

            return (bool?)reportModeProperty.GetValue(parameters);
        }

        private bool ShowExecutionApprovalDialog()
        {
            bool approved = false;

            Window dialog = new()
            {
                Title = "AutomationsGuru execution approval",
                Owner = Window.GetWindow(this),
                Width = 560,
                Height = 380,
                ResizeMode = ResizeMode.NoResize,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
            };

            StackPanel panel = new()
            {
                Margin = new Thickness(20),
            };

            panel.Children.Add(new TextBlock
            {
                Text = "This solution can change SharePoint Online or Microsoft 365 state.",
                FontWeight = FontWeights.Bold,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 12),
            });

            panel.Children.Add(new TextBlock
            {
                Text = $"Solution: {_solutionForm.SolutionName} ({_solutionForm.SolutionCode})",
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 8),
            });

            panel.Children.Add(new TextBlock
            {
                Text = "Run mode: Execute. Reports and report-mode runs do not require this gate.",
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 8),
            });

            panel.Children.Add(new TextBlock
            {
                Text = "Tenant mutation possibility: Possible. Source/content mutation possibility: Possible.",
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 8),
            });

            panel.Children.Add(new TextBlock
            {
                Text = $"Evidence folder pattern: {Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments)}\\NovaPoint\\{_solutionForm.SolutionName}\\<run timestamp>",
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 8),
            });

            panel.Children.Add(new TextBlock
            {
                Text = $"Type {ExecuteApprovalPhrase} to continue.",
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 8),
            });

            TextBox approvalText = new()
            {
                Margin = new Thickness(0, 0, 0, 16),
            };
            panel.Children.Add(approvalText);

            StackPanel buttons = new()
            {
                Orientation = Orientation.Horizontal,
                HorizontalAlignment = HorizontalAlignment.Right,
            };

            Button cancelButton = new()
            {
                Content = "Cancel",
                Width = 110,
                Margin = new Thickness(0, 0, 8, 0),
            };

            Button approveButton = new()
            {
                Content = "Run",
                Width = 110,
                IsEnabled = false,
            };

            approvalText.TextChanged += (_, _) =>
            {
                approveButton.IsEnabled = string.Equals(approvalText.Text, ExecuteApprovalPhrase, StringComparison.Ordinal);
            };

            cancelButton.Click += (_, _) =>
            {
                dialog.DialogResult = false;
                dialog.Close();
            };

            approveButton.Click += (_, _) =>
            {
                approved = true;
                dialog.DialogResult = true;
                dialog.Close();
            };

            buttons.Children.Add(cancelButton);
            buttons.Children.Add(approveButton);
            panel.Children.Add(buttons);

            dialog.Content = panel;
            dialog.ShowDialog();

            return approved;
        }

    }
}
