#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-maui-blazor-app" "$@"
create_project_dir

SAFE_NAME=$(echo "$PROJECT_NAME" | sed 's/[-]/_/g')

# --- .csproj ---
write_file_heredoc "${PROJECT_NAME}.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk.Razor">

  <PropertyGroup>
    <TargetFrameworks>net9.0-android;net9.0-ios;net9.0-maccatalyst</TargetFrameworks>
    <TargetFrameworks Condition="\$([MSBuild]::IsOSPlatform('windows'))">\$(TargetFrameworks);net9.0-windows10.0.19041.0</TargetFrameworks>
    <OutputType>Exe</OutputType>
    <RootNamespace>${SAFE_NAME}</RootNamespace>
    <UseMaui>true</UseMaui>
    <SingleProject>true</SingleProject>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <EnableDefaultCssItems>false</EnableDefaultCssItems>

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
    <PackageReference Include="Microsoft.AspNetCore.Components.WebView.Maui" Version="9.*" />
    <PackageReference Include="MudBlazor" Version="7.*" />
    <PackageReference Include="Microsoft.Extensions.Logging.Debug" Version="9.*" />
  </ItemGroup>

</Project>
EOF

# --- MauiProgram.cs ---
write_file_heredoc "MauiProgram.cs" << EOF
using Microsoft.Extensions.Logging;
using MudBlazor.Services;

namespace ${SAFE_NAME};

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
            });

        builder.Services.AddMauiBlazorWebView();
        builder.Services.AddMudServices();

#if DEBUG
        builder.Services.AddBlazorWebViewDeveloperTools();
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
        return new Window(new MainPage());
    }
}
EOF

# --- MainPage.xaml ---
write_file_heredoc "MainPage.xaml" << EOF
<?xml version="1.0" encoding="utf-8" ?>
<ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             xmlns:local="clr-namespace:${SAFE_NAME}"
             x:Class="${SAFE_NAME}.MainPage"
             BackgroundColor="{DynamicResource PageBackgroundColor}">

    <BlazorWebView x:Name="blazorWebView" HostPage="wwwroot/index.html">
        <BlazorWebView.RootComponents>
            <RootComponent Selector="#app" ComponentType="{x:Type local:Components.Routes}" />
        </BlazorWebView.RootComponents>
    </BlazorWebView>

</ContentPage>
EOF

# --- MainPage.xaml.cs ---
write_file_heredoc "MainPage.xaml.cs" << EOF
namespace ${SAFE_NAME};

public partial class MainPage : ContentPage
{
    public MainPage()
    {
        InitializeComponent();
    }
}
EOF

# --- _Imports.razor ---
write_file_heredoc "_Imports.razor" << EOF
@using System.Net.Http
@using Microsoft.AspNetCore.Components.Forms
@using Microsoft.AspNetCore.Components.Routing
@using Microsoft.AspNetCore.Components.Web
@using Microsoft.AspNetCore.Components.Web.Virtualization
@using Microsoft.JSInterop
@using MudBlazor
@using ${SAFE_NAME}
@using ${SAFE_NAME}.Components
@using ${SAFE_NAME}.Components.Layout
@using ${SAFE_NAME}.Components.Pages
EOF

# --- Components/Routes.razor ---
write_file_heredoc "Components/Routes.razor" << 'EOF'
<Router AppAssembly="@typeof(Routes).Assembly">
    <Found Context="routeData">
        <RouteView RouteData="@routeData" DefaultLayout="@typeof(Layout.MainLayout)" />
        <FocusOnNavigate RouteData="@routeData" Selector="h1" />
    </Found>
    <NotFound>
        <LayoutView Layout="@typeof(Layout.MainLayout)">
            <MudText Typo="Typo.h4" Align="Align.Center" Class="mt-8">
                Page not found
            </MudText>
            <MudText Align="Align.Center" Class="mt-2">
                Sorry, the page you are looking for does not exist.
            </MudText>
        </LayoutView>
    </NotFound>
</Router>
EOF

# --- Components/Layout/MainLayout.razor ---
write_file_heredoc "Components/Layout/MainLayout.razor" << 'EOF'
@inherits LayoutComponentBase

<MudThemeProvider @bind-IsDarkMode="@_isDarkMode" Theme="@_theme" />
<MudPopoverProvider />
<MudDialogProvider />
<MudSnackbarProvider />

<MudLayout>
    <MudAppBar Elevation="1">
        <MudIconButton Icon="@Icons.Material.Filled.Menu" Color="Color.Inherit" Edge="Edge.Start" OnClick="@ToggleDrawer" />
        <MudText Typo="Typo.h5" Class="ml-3">MAUI Blazor App</MudText>
        <MudSpacer />
        <MudIconButton Icon="@(_isDarkMode ? Icons.Material.Filled.LightMode : Icons.Material.Filled.DarkMode)"
                       Color="Color.Inherit" OnClick="@ToggleDarkMode" />
    </MudAppBar>

    <MudDrawer @bind-Open="_drawerOpen" ClipMode="DrawerClipMode.Always" Elevation="2">
        <NavMenu />
    </MudDrawer>

    <MudMainContent Class="pt-16 px-4">
        @Body
    </MudMainContent>
</MudLayout>

@code {
    private bool _drawerOpen = true;
    private bool _isDarkMode = false;

    private MudTheme _theme = new()
    {
        PaletteLight = new PaletteLight
        {
            Primary = "#512BD4",
            Secondary = "#DFD8F7",
            AppbarBackground = "#512BD4"
        },
        PaletteDark = new PaletteDark
        {
            Primary = "#ac99ea",
            Secondary = "#9880e5",
            AppbarBackground = "#1e1e2e"
        }
    };

    private void ToggleDrawer() => _drawerOpen = !_drawerOpen;
    private void ToggleDarkMode() => _isDarkMode = !_isDarkMode;
}
EOF

# --- Components/Layout/NavMenu.razor ---
write_file_heredoc "Components/Layout/NavMenu.razor" << 'EOF'
<MudNavMenu>
    <MudNavLink Href="/" Match="NavLinkMatch.All" Icon="@Icons.Material.Filled.Home">Home</MudNavLink>
    <MudNavLink Href="/counter" Match="NavLinkMatch.Prefix" Icon="@Icons.Material.Filled.AddCircle">Counter</MudNavLink>
    <MudNavLink Href="/todo" Match="NavLinkMatch.Prefix" Icon="@Icons.Material.Filled.Checklist">Todo</MudNavLink>
</MudNavMenu>
EOF

# --- Components/Pages/Home.razor ---
write_file_heredoc "Components/Pages/Home.razor" << 'EOF'
@page "/"

<MudContainer MaxWidth="MaxWidth.Medium" Class="mt-8">
    <MudText Typo="Typo.h3" GutterBottom="true">Welcome!</MudText>
    <MudText Typo="Typo.body1" Class="mb-8">
        This is a .NET MAUI Blazor Hybrid app with MudBlazor components.
    </MudText>

    <MudGrid>
        <MudItem xs="12" sm="6">
            <MudCard>
                <MudCardContent>
                    <MudText Typo="Typo.h5">Cross-Platform</MudText>
                    <MudText Typo="Typo.body2">
                        Build once, run on Android, iOS, macOS, and Windows.
                    </MudText>
                </MudCardContent>
                <MudCardActions>
                    <MudButton Variant="Variant.Text" Color="Color.Primary"
                               Href="https://learn.microsoft.com/dotnet/maui/" Target="_blank">
                        Learn More
                    </MudButton>
                </MudCardActions>
            </MudCard>
        </MudItem>
        <MudItem xs="12" sm="6">
            <MudCard>
                <MudCardContent>
                    <MudText Typo="Typo.h5">MudBlazor</MudText>
                    <MudText Typo="Typo.body2">
                        Material Design components for Blazor with full theming support.
                    </MudText>
                </MudCardContent>
                <MudCardActions>
                    <MudButton Variant="Variant.Text" Color="Color.Primary"
                               Href="https://mudblazor.com/" Target="_blank">
                        Explore
                    </MudButton>
                </MudCardActions>
            </MudCard>
        </MudItem>
    </MudGrid>
</MudContainer>
EOF

# --- Components/Pages/Counter.razor ---
write_file_heredoc "Components/Pages/Counter.razor" << 'EOF'
@page "/counter"

<MudContainer MaxWidth="MaxWidth.Small" Class="mt-8">
    <MudText Typo="Typo.h3" GutterBottom="true">Counter</MudText>

    <MudPaper Class="pa-8 d-flex flex-column align-center gap-4" Elevation="2">
        <MudText Typo="Typo.h1">@currentCount</MudText>
        <MudButton Variant="Variant.Filled" Color="Color.Primary"
                   StartIcon="@Icons.Material.Filled.Add" OnClick="IncrementCount">
            Click me
        </MudButton>
    </MudPaper>
</MudContainer>

@code {
    private int currentCount = 0;

    private void IncrementCount()
    {
        currentCount++;
    }
}
EOF

# --- Components/Pages/Todo.razor ---
write_file_heredoc "Components/Pages/Todo.razor" << 'EOF'
@page "/todo"

<MudContainer MaxWidth="MaxWidth.Medium" Class="mt-8">
    <MudText Typo="Typo.h3" GutterBottom="true">Todo List</MudText>

    <MudPaper Class="pa-4 mb-4" Elevation="2">
        <MudGrid>
            <MudItem xs="9" sm="10">
                <MudTextField @bind-Value="newTodo" Label="New todo" Variant="Variant.Outlined"
                              Adornment="Adornment.Start" AdornmentIcon="@Icons.Material.Filled.Edit"
                              OnKeyDown="@HandleKeyDown" />
            </MudItem>
            <MudItem xs="3" sm="2" Class="d-flex align-center">
                <MudButton Variant="Variant.Filled" Color="Color.Primary" FullWidth="true"
                           OnClick="AddTodo" Disabled="@string.IsNullOrWhiteSpace(newTodo)">
                    Add
                </MudButton>
            </MudItem>
        </MudGrid>
    </MudPaper>

    <MudList T="TodoItem">
        @foreach (var todo in todos)
        {
            <MudListItem>
                <div class="d-flex align-center">
                    <MudCheckBox @bind-Value="@todo.IsCompleted" Color="Color.Primary" />
                    <MudText Style="@(todo.IsCompleted ? "text-decoration: line-through; opacity: 0.6" : "")">
                        @todo.Title
                    </MudText>
                    <MudSpacer />
                    <MudIconButton Icon="@Icons.Material.Filled.Delete" Color="Color.Error"
                                   OnClick="@(() => RemoveTodo(todo))" />
                </div>
            </MudListItem>
        }
    </MudList>

    @if (!todos.Any())
    {
        <MudAlert Severity="Severity.Info" Class="mt-4">
            No todos yet. Add one above!
        </MudAlert>
    }
</MudContainer>

@code {
    private string newTodo = "";
    private List<TodoItem> todos = new()
    {
        new() { Title = "Learn Blazor Hybrid" },
        new() { Title = "Add MudBlazor components" },
        new() { Title = "Deploy to devices" },
    };

    private void AddTodo()
    {
        if (!string.IsNullOrWhiteSpace(newTodo))
        {
            todos.Add(new TodoItem { Title = newTodo });
            newTodo = "";
        }
    }

    private void RemoveTodo(TodoItem item) => todos.Remove(item);

    private void HandleKeyDown(KeyboardEventArgs e)
    {
        if (e.Key == "Enter") AddTodo();
    }

    private class TodoItem
    {
        public string Title { get; set; } = "";
        public bool IsCompleted { get; set; }
    }
}
EOF

# --- wwwroot/index.html ---
write_file_heredoc "wwwroot/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <title>MAUI Blazor App</title>
    <base href="/" />
    <link href="https://fonts.googleapis.com/css?family=Roboto:300,400,500,700&display=swap" rel="stylesheet" />
    <link href="_content/MudBlazor/MudBlazor.min.css" rel="stylesheet" />
    <link href="css/app.css" rel="stylesheet" />
</head>
<body>
    <div id="app">Loading...</div>

    <div id="blazor-error-ui">
        An unhandled error has occurred.
        <a href="" class="reload">Reload</a>
        <a class="dismiss">Dismiss</a>
    </div>

    <script src="_content/MudBlazor/MudBlazor.min.js"></script>
    <script src="_framework/blazor.webview.js" autostart="false"></script>
</body>
</html>
EOF

# --- wwwroot/css/app.css ---
write_file_heredoc "wwwroot/css/app.css" << 'EOF'
html, body {
    font-family: 'Roboto', 'Helvetica', 'Arial', sans-serif;
}

#blazor-error-ui {
    background: lightyellow;
    bottom: 0;
    box-shadow: 0 -1px 2px rgba(0, 0, 0, 0.2);
    display: none;
    left: 0;
    padding: 0.6rem 1.25rem 0.7rem 1.25rem;
    position: fixed;
    width: 100%;
    z-index: 1000;
}

#blazor-error-ui .dismiss {
    cursor: pointer;
    position: absolute;
    right: 0.75rem;
    top: 0.5rem;
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
    <Color x:Key="White">White</Color>
    <Color x:Key="Black">Black</Color>
</ResourceDictionary>
EOF

# --- Platforms ---
write_file_heredoc "Platforms/Android/AndroidManifest.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:allowBackup="true" android:supportsRtl="true" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>
EOF

write_file_heredoc "Platforms/Android/MainApplication.cs" << EOF
using Android.App;
using Android.Runtime;

namespace ${SAFE_NAME};

[Application]
public class MainApplication : MauiApplication
{
    public MainApplication(IntPtr handle, JniHandleOwnership ownership)
        : base(handle, ownership) { }

    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
EOF

write_file_heredoc "Platforms/Android/MainActivity.cs" << EOF
using Android.App;
using Android.Content.PM;

namespace ${SAFE_NAME};

[Activity(Theme = "@style/Maui.SplashTheme", MainLauncher = true,
    ConfigurationChanges = ConfigChanges.ScreenSize | ConfigChanges.Orientation |
    ConfigChanges.UiMode | ConfigChanges.ScreenLayout | ConfigChanges.SmallestScreenSize |
    ConfigChanges.Density)]
public class MainActivity : MauiAppCompatActivity { }
EOF

write_file_heredoc "Platforms/iOS/AppDelegate.cs" << EOF
using Foundation;

namespace ${SAFE_NAME};

[Register("AppDelegate")]
public class AppDelegate : MauiUIApplicationDelegate
{
    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
EOF

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

mkdir -p Resources/Fonts Resources/Images Resources/Raw

init_git
write_gitignore \
  "bin/" \
  "obj/" \
  "*.user" \
  "*.suo" \
  "*.vs/" \
  "*.DotSettings.user"
write_editorconfig

write_readme "$PROJECT_NAME" "A .NET 9 MAUI Blazor Hybrid app with MudBlazor components." \
  "dotnet restore" \
  "dotnet build" \
  "- \`dotnet build\` - Build the project
- \`dotnet build -t:Run -f net9.0-android\` - Run on Android
- \`dotnet build -t:Run -f net9.0-ios\` - Run on iOS"

finish "dotnet restore" "dotnet build"
