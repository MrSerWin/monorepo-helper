#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-maui-app" "$@"
create_project_dir

SAFE_NAME=$(echo "$PROJECT_NAME" | sed 's/[-]/_/g')

# --- .csproj ---
write_file_heredoc "${PROJECT_NAME}.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFrameworks>net9.0-android;net9.0-ios;net9.0-maccatalyst</TargetFrameworks>
    <TargetFrameworks Condition="\$([MSBuild]::IsOSPlatform('windows'))">\$(TargetFrameworks);net9.0-windows10.0.19041.0</TargetFrameworks>
    <OutputType>Exe</OutputType>
    <RootNamespace>${SAFE_NAME}</RootNamespace>
    <UseMaui>true</UseMaui>
    <SingleProject>true</SingleProject>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>

    <ApplicationTitle>${PROJECT_NAME}</ApplicationTitle>
    <ApplicationId>com.example.${SAFE_NAME}</ApplicationId>
    <ApplicationDisplayVersion>1.0</ApplicationDisplayVersion>
    <ApplicationVersion>1</ApplicationVersion>

    <SupportedOSPlatformVersion Condition="\$([MSBuild]::GetTargetPlatformIdentifier('\$(TargetFramework)')) == 'ios'">15.0</SupportedOSPlatformVersion>
    <SupportedOSPlatformVersion Condition="\$([MSBuild]::GetTargetPlatformIdentifier('\$(TargetFramework)')) == 'maccatalyst'">15.0</SupportedOSPlatformVersion>
    <SupportedOSPlatformVersion Condition="\$([MSBuild]::GetTargetPlatformIdentifier('\$(TargetFramework)')) == 'android'">24.0</SupportedOSPlatformVersion>
    <SupportedOSPlatformVersion Condition="\$([MSBuild]::GetTargetPlatformIdentifier('\$(TargetFramework)')) == 'windows'">10.0.17763.0</SupportedOSPlatformVersion>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Maui.Controls" Version="9.*" />
    <PackageReference Include="Microsoft.Maui.Controls.Compatibility" Version="9.*" />
    <PackageReference Include="CommunityToolkit.Mvvm" Version="8.*" />
    <PackageReference Include="CommunityToolkit.Maui" Version="9.*" />
    <PackageReference Include="Microsoft.Extensions.Logging.Debug" Version="9.*" />
  </ItemGroup>

</Project>
EOF

# --- MauiProgram.cs ---
write_file_heredoc "MauiProgram.cs" << EOF
using CommunityToolkit.Maui;
using Microsoft.Extensions.Logging;
using ${SAFE_NAME}.ViewModels;
using ${SAFE_NAME}.Views;

namespace ${SAFE_NAME};

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseMauiCommunityToolkit()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
            });

        // Register services
        builder.Services.AddSingleton<MainViewModel>();
        builder.Services.AddSingleton<MainPage>();

        builder.Services.AddTransient<DetailViewModel>();
        builder.Services.AddTransient<DetailPage>();

#if DEBUG
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}
EOF

# --- App.xaml ---
write_file_heredoc "App.xaml" << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<Application xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             x:Class="${SAFE_NAME}.App">
    <Application.Resources>
        <ResourceDictionary>
            <ResourceDictionary.MergedDictionaries>
                <ResourceDictionary Source="Resources/Styles/Colors.xaml" />
                <ResourceDictionary Source="Resources/Styles/Styles.xaml" />
            </ResourceDictionary.MergedDictionaries>
        </ResourceDictionary>
    </Application.Resources>
</Application>
EOF

# --- App.xaml.cs ---
write_file_heredoc "App.xaml.cs" << EOF
namespace ${SAFE_NAME};

public partial class App : Application
{
    public App()
    {
        InitializeComponent();
    }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        return new Window(new AppShell());
    }
}
EOF

# --- AppShell.xaml ---
write_file_heredoc "AppShell.xaml" << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<Shell xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
       xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
       xmlns:views="clr-namespace:${SAFE_NAME}.Views"
       x:Class="${SAFE_NAME}.AppShell"
       Shell.FlyoutBehavior="Disabled">

    <ShellContent
        Title="Home"
        ContentTemplate="{DataTemplate views:MainPage}"
        Route="MainPage" />

</Shell>
EOF

# --- AppShell.xaml.cs ---
write_file_heredoc "AppShell.xaml.cs" << EOF
namespace ${SAFE_NAME};

public partial class AppShell : Shell
{
    public AppShell()
    {
        InitializeComponent();
        Routing.RegisterRoute(nameof(Views.DetailPage), typeof(Views.DetailPage));
    }
}
EOF

# --- Models/TodoItem.cs ---
write_file_heredoc "Models/TodoItem.cs" << EOF
namespace ${SAFE_NAME}.Models;

public class TodoItem
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public bool IsCompleted { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}
EOF

# --- ViewModels/MainViewModel.cs ---
write_file_heredoc "ViewModels/MainViewModel.cs" << EOF
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using System.Collections.ObjectModel;
using ${SAFE_NAME}.Models;

namespace ${SAFE_NAME}.ViewModels;

public partial class MainViewModel : ObservableObject
{
    [ObservableProperty]
    private string _newItemTitle = string.Empty;

    public ObservableCollection<TodoItem> Items { get; } = new()
    {
        new TodoItem { Id = 1, Title = "Learn .NET MAUI", Description = "Build cross-platform apps" },
        new TodoItem { Id = 2, Title = "Use CommunityToolkit", Description = "MVVM made easy" },
        new TodoItem { Id = 3, Title = "Ship the app", Description = "Deploy to stores" },
    };

    private int _nextId = 4;

    [RelayCommand]
    private void AddItem()
    {
        if (string.IsNullOrWhiteSpace(NewItemTitle))
            return;

        Items.Add(new TodoItem
        {
            Id = _nextId++,
            Title = NewItemTitle,
            Description = "Added from the app"
        });

        NewItemTitle = string.Empty;
    }

    [RelayCommand]
    private void ToggleItem(TodoItem item)
    {
        item.IsCompleted = !item.IsCompleted;
    }

    [RelayCommand]
    private void DeleteItem(TodoItem item)
    {
        Items.Remove(item);
    }

    [RelayCommand]
    private async Task GoToDetail(TodoItem item)
    {
        await Shell.Current.GoToAsync(nameof(Views.DetailPage), new Dictionary<string, object>
        {
            { "Item", item }
        });
    }
}
EOF

# --- ViewModels/DetailViewModel.cs ---
write_file_heredoc "ViewModels/DetailViewModel.cs" << EOF
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using ${SAFE_NAME}.Models;

namespace ${SAFE_NAME}.ViewModels;

[QueryProperty(nameof(Item), "Item")]
public partial class DetailViewModel : ObservableObject
{
    [ObservableProperty]
    private TodoItem? _item;

    [RelayCommand]
    private async Task GoBack()
    {
        await Shell.Current.GoToAsync("..");
    }
}
EOF

# --- Views/MainPage.xaml ---
write_file_heredoc "Views/MainPage.xaml" << EOF
<?xml version="1.0" encoding="utf-8" ?>
<ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             xmlns:vm="clr-namespace:${SAFE_NAME}.ViewModels"
             x:Class="${SAFE_NAME}.Views.MainPage"
             Title="Todo List">

    <Grid RowDefinitions="Auto,*" Padding="16" RowSpacing="16">

        <!-- Add Item -->
        <HorizontalStackLayout Spacing="8">
            <Entry Text="{Binding NewItemTitle}"
                   Placeholder="Add new item..."
                   HorizontalOptions="FillAndExpand"
                   ReturnCommand="{Binding AddItemCommand}" />
            <Button Text="Add"
                    Command="{Binding AddItemCommand}"
                    BackgroundColor="{StaticResource Primary}"
                    TextColor="White" />
        </HorizontalStackLayout>

        <!-- Item List -->
        <CollectionView Grid.Row="1"
                        ItemsSource="{Binding Items}"
                        EmptyView="No items yet. Add one above!">
            <CollectionView.ItemTemplate>
                <DataTemplate>
                    <SwipeView>
                        <SwipeView.RightItems>
                            <SwipeItems>
                                <SwipeItem Text="Delete"
                                           BackgroundColor="Red"
                                           Command="{Binding Source={RelativeSource AncestorType={x:Type vm:MainViewModel}}, Path=DeleteItemCommand}"
                                           CommandParameter="{Binding}" />
                            </SwipeItems>
                        </SwipeView.RightItems>
                        <Frame Padding="12" Margin="0,4" HasShadow="False" BorderColor="LightGray">
                            <Frame.GestureRecognizers>
                                <TapGestureRecognizer
                                    Command="{Binding Source={RelativeSource AncestorType={x:Type vm:MainViewModel}}, Path=GoToDetailCommand}"
                                    CommandParameter="{Binding}" />
                            </Frame.GestureRecognizers>
                            <HorizontalStackLayout Spacing="12">
                                <CheckBox IsChecked="{Binding IsCompleted}"
                                          Color="{StaticResource Primary}" />
                                <VerticalStackLayout VerticalOptions="Center">
                                    <Label Text="{Binding Title}" FontSize="16" FontAttributes="Bold" />
                                    <Label Text="{Binding Description}" FontSize="12" TextColor="Gray" />
                                </VerticalStackLayout>
                            </HorizontalStackLayout>
                        </Frame>
                    </SwipeView>
                </DataTemplate>
            </CollectionView.ItemTemplate>
        </CollectionView>
    </Grid>
</ContentPage>
EOF

# --- Views/MainPage.xaml.cs ---
write_file_heredoc "Views/MainPage.xaml.cs" << EOF
using ${SAFE_NAME}.ViewModels;

namespace ${SAFE_NAME}.Views;

public partial class MainPage : ContentPage
{
    public MainPage(MainViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }
}
EOF

# --- Views/DetailPage.xaml ---
write_file_heredoc "Views/DetailPage.xaml" << EOF
<?xml version="1.0" encoding="utf-8" ?>
<ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             x:Class="${SAFE_NAME}.Views.DetailPage"
             Title="Item Detail">

    <VerticalStackLayout Padding="24" Spacing="16">
        <Label Text="{Binding Item.Title}" FontSize="28" FontAttributes="Bold" />
        <Label Text="{Binding Item.Description}" FontSize="16" TextColor="Gray" />
        <Label FontSize="14" TextColor="DimGray">
            <Label.Text>
                <MultiBinding StringFormat="Created: {0:MMM dd, yyyy} | Completed: {1}">
                    <Binding Path="Item.CreatedAt" />
                    <Binding Path="Item.IsCompleted" />
                </MultiBinding>
            </Label.Text>
        </Label>
        <Button Text="Go Back" Command="{Binding GoBackCommand}" />
    </VerticalStackLayout>
</ContentPage>
EOF

# --- Views/DetailPage.xaml.cs ---
write_file_heredoc "Views/DetailPage.xaml.cs" << EOF
using ${SAFE_NAME}.ViewModels;

namespace ${SAFE_NAME}.Views;

public partial class DetailPage : ContentPage
{
    public DetailPage(DetailViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }
}
EOF

# --- Resources/Styles/Colors.xaml ---
write_file_heredoc "Resources/Styles/Colors.xaml" << 'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<?xaml-comp compile="true" ?>
<ResourceDictionary
    xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
    xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml">

    <Color x:Key="Primary">#512BD4</Color>
    <Color x:Key="PrimaryDark">#ac99ea</Color>
    <Color x:Key="PrimaryDarkText">#242424</Color>
    <Color x:Key="Secondary">#DFD8F7</Color>
    <Color x:Key="SecondaryDarkText">#9880e5</Color>
    <Color x:Key="Tertiary">#2B0B98</Color>
    <Color x:Key="White">White</Color>
    <Color x:Key="Black">Black</Color>
    <Color x:Key="Gray100">#E1E1E1</Color>
    <Color x:Key="Gray200">#C8C8C8</Color>
    <Color x:Key="Gray300">#ACACAC</Color>
    <Color x:Key="Gray400">#919191</Color>
    <Color x:Key="Gray500">#6E6E6E</Color>
    <Color x:Key="Gray600">#404040</Color>
    <Color x:Key="Gray900">#212121</Color>
    <Color x:Key="Gray950">#141414</Color>

</ResourceDictionary>
EOF

# --- Resources/Styles/Styles.xaml ---
write_file_heredoc "Resources/Styles/Styles.xaml" << 'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<?xaml-comp compile="true" ?>
<ResourceDictionary
    xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
    xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml">

    <Style TargetType="Page" ApplyToDerivedTypes="True">
        <Setter Property="BackgroundColor" Value="{AppThemeBinding Light={StaticResource White}, Dark={StaticResource Black}}" />
    </Style>

    <Style TargetType="NavigationPage">
        <Setter Property="BarBackgroundColor" Value="{AppThemeBinding Light={StaticResource Primary}, Dark={StaticResource Gray950}}" />
        <Setter Property="BarTextColor" Value="{AppThemeBinding Light={StaticResource White}, Dark={StaticResource White}}" />
    </Style>

    <Style TargetType="Shell" ApplyToDerivedTypes="True">
        <Setter Property="Shell.BackgroundColor" Value="{AppThemeBinding Light={StaticResource Primary}, Dark={StaticResource Gray950}}" />
        <Setter Property="Shell.ForegroundColor" Value="{AppThemeBinding Light={StaticResource White}, Dark={StaticResource White}}" />
    </Style>

</ResourceDictionary>
EOF

# --- Platforms/Android/AndroidManifest.xml ---
write_file_heredoc "Platforms/Android/AndroidManifest.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:allowBackup="true"
                 android:icon="@mipmap/appicon"
                 android:roundIcon="@mipmap/appicon_round"
                 android:supportsRtl="true">
    </application>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>
EOF

# --- Platforms/Android/MainApplication.cs ---
write_file_heredoc "Platforms/Android/MainApplication.cs" << EOF
using Android.App;
using Android.Runtime;

namespace ${SAFE_NAME};

[Application]
public class MainApplication : MauiApplication
{
    public MainApplication(IntPtr handle, JniHandleOwnership ownership)
        : base(handle, ownership)
    {
    }

    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
EOF

# --- Platforms/Android/MainActivity.cs ---
write_file_heredoc "Platforms/Android/MainActivity.cs" << EOF
using Android.App;
using Android.Content.PM;

namespace ${SAFE_NAME};

[Activity(Theme = "@style/Maui.SplashTheme", MainLauncher = true,
    ConfigurationChanges = ConfigChanges.ScreenSize | ConfigChanges.Orientation |
    ConfigChanges.UiMode | ConfigChanges.ScreenLayout | ConfigChanges.SmallestScreenSize |
    ConfigChanges.Density)]
public class MainActivity : MauiAppCompatActivity
{
}
EOF

# --- Platforms/iOS/AppDelegate.cs ---
write_file_heredoc "Platforms/iOS/AppDelegate.cs" << EOF
using Foundation;

namespace ${SAFE_NAME};

[Register("AppDelegate")]
public class AppDelegate : MauiUIApplicationDelegate
{
    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
EOF

# --- Platforms/iOS/Program.cs ---
write_file_heredoc "Platforms/iOS/Program.cs" << EOF
using UIKit;

namespace ${SAFE_NAME};

public class Program
{
    static void Main(string[] args)
    {
        UIApplication.Main(args, null, typeof(AppDelegate));
    }
}
EOF

# --- Platforms/iOS/Info.plist ---
write_file_heredoc "Platforms/iOS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
EOF

# Create resource directory structure
mkdir -p Resources/Fonts
mkdir -p Resources/Images
mkdir -p Resources/Raw
mkdir -p Resources/Splash

init_git
write_gitignore \
  "bin/" \
  "obj/" \
  "*.user" \
  "*.suo" \
  "*.vs/" \
  "*.DotSettings.user"
write_editorconfig

write_readme "$PROJECT_NAME" "A .NET 9 MAUI app with CommunityToolkit MVVM pattern." \
  "dotnet restore" \
  "dotnet build" \
  "- \`dotnet build\` - Build the project
- \`dotnet build -t:Run -f net9.0-android\` - Run on Android
- \`dotnet build -t:Run -f net9.0-ios\` - Run on iOS"

finish "dotnet restore" "dotnet build"
