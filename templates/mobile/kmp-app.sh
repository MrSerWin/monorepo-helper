#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-kmp-app" "$@"
create_project_dir

# --- settings.gradle.kts ---
write_file_heredoc "settings.gradle.kts" << SETTINGSEOF
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "${PROJECT_NAME}"
include(":shared")
include(":composeApp")
SETTINGSEOF

# --- gradle.properties ---
write_file_heredoc "gradle.properties" << 'EOF'
org.gradle.jvmargs=-Xmx2048M -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
kotlin.mpp.androidSourceSetLayoutVersion=2
org.jetbrains.compose.experimental.macos.enabled=true
org.jetbrains.compose.experimental.jscanvas.enabled=true
EOF

# --- build.gradle.kts (root) ---
write_file_heredoc "build.gradle.kts" << 'EOF'
plugins {
    alias(libs.plugins.androidApplication) apply false
    alias(libs.plugins.androidLibrary) apply false
    alias(libs.plugins.kotlinMultiplatform) apply false
    alias(libs.plugins.composeMultiplatform) apply false
    alias(libs.plugins.composeCompiler) apply false
    alias(libs.plugins.kotlinxSerialization) apply false
}
EOF

# --- gradle/libs.versions.toml ---
write_file_heredoc "gradle/libs.versions.toml" << 'EOF'
[versions]
agp = "8.7.3"
kotlin = "2.1.10"
compose-multiplatform = "1.7.3"
koin = "4.0.2"
ktor = "3.0.3"
coroutines = "1.9.0"
serialization = "1.7.3"
lifecycle = "2.8.4"
navigation = "2.8.0-alpha10"
androidMinSdk = "24"
androidCompileSdk = "35"
androidTargetSdk = "35"

[libraries]
# Koin
koin-core = { module = "io.insert-koin:koin-core", version.ref = "koin" }
koin-compose = { module = "io.insert-koin:koin-compose", version.ref = "koin" }
koin-compose-viewmodel = { module = "io.insert-koin:koin-compose-viewmodel", version.ref = "koin" }

# Ktor
ktor-client-core = { module = "io.ktor:ktor-client-core", version.ref = "ktor" }
ktor-client-content-negotiation = { module = "io.ktor:ktor-client-content-negotiation", version.ref = "ktor" }
ktor-serialization-json = { module = "io.ktor:ktor-serialization-kotlinx-json", version.ref = "ktor" }
ktor-client-okhttp = { module = "io.ktor:ktor-client-okhttp", version.ref = "ktor" }
ktor-client-darwin = { module = "io.ktor:ktor-client-darwin", version.ref = "ktor" }

# Coroutines
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "coroutines" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version.ref = "serialization" }

# Lifecycle
lifecycle-viewmodel-compose = { module = "org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose", version.ref = "lifecycle" }
navigation-compose = { module = "org.jetbrains.androidx.navigation:navigation-compose", version.ref = "navigation" }

[plugins]
androidApplication = { id = "com.android.application", version.ref = "agp" }
androidLibrary = { id = "com.android.library", version.ref = "agp" }
kotlinMultiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }
composeMultiplatform = { id = "org.jetbrains.compose", version.ref = "compose-multiplatform" }
composeCompiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
kotlinxSerialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
EOF

# --- shared/build.gradle.kts ---
write_file_heredoc "shared/build.gradle.kts" << 'EOF'
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidLibrary)
    alias(libs.plugins.kotlinxSerialization)
}

kotlin {
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }

    listOf(
        iosX64(),
        iosArm64(),
        iosSimulatorArm64()
    ).forEach {
        it.binaries.framework {
            baseName = "shared"
            isStatic = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.koin.core)
            implementation(libs.ktor.client.core)
            implementation(libs.ktor.client.content.negotiation)
            implementation(libs.ktor.serialization.json)
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.serialization.json)
        }
        androidMain.dependencies {
            implementation(libs.ktor.client.okhttp)
        }
        iosMain.dependencies {
            implementation(libs.ktor.client.darwin)
        }
    }
}

android {
    namespace = "com.example.${PROJECT_NAME.replace("-", "")}.shared"
    compileSdk = libs.versions.androidCompileSdk.get().toInt()
    defaultConfig {
        minSdk = libs.versions.androidMinSdk.get().toInt()
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
EOF

# --- shared/src/commonMain/kotlin/data/model/Post.kt ---
write_file_heredoc "shared/src/commonMain/kotlin/data/model/Post.kt" << 'EOF'
package data.model

import kotlinx.serialization.Serializable

@Serializable
data class Post(
    val id: Int,
    val userId: Int,
    val title: String,
    val body: String
)
EOF

# --- shared/src/commonMain/kotlin/data/remote/ApiClient.kt ---
write_file_heredoc "shared/src/commonMain/kotlin/data/remote/ApiClient.kt" << 'EOF'
package data.remote

import data.model.Post
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.json.Json

class ApiClient(private val httpClient: HttpClient) {

    suspend fun getPosts(): List<Post> {
        return httpClient.get("https://jsonplaceholder.typicode.com/posts").body()
    }

    suspend fun getPost(id: Int): Post {
        return httpClient.get("https://jsonplaceholder.typicode.com/posts/$id").body()
    }

    companion object {
        fun create(): HttpClient {
            return HttpClient {
                install(ContentNegotiation) {
                    json(Json {
                        ignoreUnknownKeys = true
                        prettyPrint = true
                        isLenient = true
                    })
                }
            }
        }
    }
}
EOF

# --- shared/src/commonMain/kotlin/data/repository/PostRepository.kt ---
write_file_heredoc "shared/src/commonMain/kotlin/data/repository/PostRepository.kt" << 'EOF'
package data.repository

import data.model.Post
import data.remote.ApiClient
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

class PostRepository(private val apiClient: ApiClient) {

    fun getPosts(): Flow<List<Post>> = flow {
        emit(apiClient.getPosts())
    }

    fun getPost(id: Int): Flow<Post> = flow {
        emit(apiClient.getPost(id))
    }
}
EOF

# --- shared/src/commonMain/kotlin/di/SharedModule.kt ---
write_file_heredoc "shared/src/commonMain/kotlin/di/SharedModule.kt" << 'EOF'
package di

import data.remote.ApiClient
import data.repository.PostRepository
import org.koin.dsl.module

val sharedModule = module {
    single { ApiClient.create() }
    single { ApiClient(get()) }
    single { PostRepository(get()) }
}
EOF

# --- shared/src/androidMain/kotlin/Platform.android.kt ---
write_file_heredoc "shared/src/androidMain/kotlin/Platform.android.kt" << 'EOF'
actual fun getPlatformName(): String = "Android"
EOF

# --- shared/src/iosMain/kotlin/Platform.ios.kt ---
write_file_heredoc "shared/src/iosMain/kotlin/Platform.ios.kt" << 'EOF'
actual fun getPlatformName(): String = "iOS"
EOF

# --- shared/src/commonMain/kotlin/Platform.kt ---
write_file_heredoc "shared/src/commonMain/kotlin/Platform.kt" << 'EOF'
expect fun getPlatformName(): String
EOF

# --- composeApp/build.gradle.kts ---
write_file_heredoc "composeApp/build.gradle.kts" << 'EOF'
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
}

kotlin {
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }

    listOf(
        iosX64(),
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "ComposeApp"
            isStatic = true
        }
    }

    sourceSets {
        androidMain.dependencies {
            implementation(libs.ktor.client.okhttp)
        }
        commonMain.dependencies {
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.ui)
            implementation(compose.components.resources)
            implementation(project(":shared"))
            implementation(libs.koin.compose)
            implementation(libs.koin.compose.viewmodel)
            implementation(libs.lifecycle.viewmodel.compose)
            implementation(libs.navigation.compose)
        }
    }
}

android {
    namespace = "com.example.${PROJECT_NAME.replace("-", "")}"
    compileSdk = libs.versions.androidCompileSdk.get().toInt()

    defaultConfig {
        applicationId = "com.example.${PROJECT_NAME.replace("-", "")}"
        minSdk = libs.versions.androidMinSdk.get().toInt()
        targetSdk = libs.versions.androidTargetSdk.get().toInt()
        versionCode = 1
        versionName = "1.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
EOF

# --- composeApp/src/commonMain/kotlin/App.kt ---
write_file_heredoc "composeApp/src/commonMain/kotlin/App.kt" << 'EOF'
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.koin.compose.viewmodel.koinViewModel
import ui.PostListViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun App() {
    MaterialTheme {
        val viewModel = koinViewModel<PostListViewModel>()
        val uiState by viewModel.uiState.collectAsState()

        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("KMP Posts") },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer
                    )
                )
            }
        ) { padding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
            ) {
                when {
                    uiState.isLoading -> {
                        CircularProgressIndicator(
                            modifier = Modifier.align(Alignment.Center)
                        )
                    }
                    uiState.error != null -> {
                        Text(
                            text = "Error: ${uiState.error}",
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.align(Alignment.Center).padding(16.dp)
                        )
                    }
                    else -> {
                        LazyColumn(
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(uiState.posts) { post ->
                                Card(
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        Text(
                                            text = post.title,
                                            style = MaterialTheme.typography.titleMedium
                                        )
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = post.body,
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
EOF

# --- composeApp/src/commonMain/kotlin/ui/PostListViewModel.kt ---
write_file_heredoc "composeApp/src/commonMain/kotlin/ui/PostListViewModel.kt" << 'EOF'
package ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import data.model.Post
import data.repository.PostRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch

data class PostListUiState(
    val posts: List<Post> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)

class PostListViewModel(
    private val postRepository: PostRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(PostListUiState())
    val uiState: StateFlow<PostListUiState> = _uiState.asStateFlow()

    init {
        loadPosts()
    }

    fun loadPosts() {
        viewModelScope.launch {
            _uiState.value = PostListUiState(isLoading = true)
            postRepository.getPosts()
                .catch { e ->
                    _uiState.value = PostListUiState(
                        isLoading = false,
                        error = e.message ?: "Unknown error"
                    )
                }
                .collect { posts ->
                    _uiState.value = PostListUiState(
                        posts = posts,
                        isLoading = false
                    )
                }
        }
    }
}
EOF

# --- composeApp/src/commonMain/kotlin/di/AppModule.kt ---
write_file_heredoc "composeApp/src/commonMain/kotlin/di/AppModule.kt" << 'EOF'
package di

import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module
import ui.PostListViewModel

val appModule = module {
    viewModel { PostListViewModel(get()) }
}
EOF

# --- composeApp/src/androidMain/kotlin/MainApplication.kt ---
PKG_NAME=$(echo "$PROJECT_NAME" | sed 's/-//g')
write_file_heredoc "composeApp/src/androidMain/kotlin/com/example/${PKG_NAME}/MainApplication.kt" << EOF
package com.example.${PKG_NAME}

import android.app.Application
import di.appModule
import di.sharedModule
import org.koin.core.context.startKoin

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            modules(sharedModule, appModule)
        }
    }
}
EOF

# --- composeApp/src/androidMain/kotlin/MainActivity.kt ---
write_file_heredoc "composeApp/src/androidMain/kotlin/com/example/${PKG_NAME}/MainActivity.kt" << EOF
package com.example.${PKG_NAME}

import App
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            App()
        }
    }
}
EOF

# --- composeApp/src/androidMain/AndroidManifest.xml ---
write_file_heredoc "composeApp/src/androidMain/AndroidManifest.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:name=".MainApplication"
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="${PROJECT_NAME}"
        android:supportsRtl="true"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# --- composeApp/src/iosMain/kotlin/MainViewController.kt ---
write_file_heredoc "composeApp/src/iosMain/kotlin/MainViewController.kt" << 'EOF'
import androidx.compose.ui.window.ComposeUIViewController

fun MainViewController() = ComposeUIViewController { App() }
EOF

# --- iosApp/iosApp.swift ---
write_file_heredoc "iosApp/iosApp/iOSApp.swift" << 'EOF'
import SwiftUI

@main
struct iOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF

# --- iosApp/ContentView.swift ---
write_file_heredoc "iosApp/iosApp/ContentView.swift" << 'EOF'
import UIKit
import SwiftUI
import ComposeApp

struct ComposeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        MainViewControllerKt.MainViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        ComposeView()
            .ignoresSafeArea(.keyboard)
    }
}
EOF

# --- gradlew placeholder ---
write_file_heredoc "gradlew" << 'EOF'
#!/usr/bin/env sh
# Gradle wrapper placeholder
# Download the real Gradle wrapper: gradle wrapper --gradle-version=8.11
echo "Please run 'gradle wrapper' to generate the Gradle wrapper"
exit 1
EOF
chmod +x gradlew

init_git
write_gitignore \
  ".gradle/" \
  "build/" \
  "*/build/" \
  "local.properties" \
  "*.iml" \
  ".kotlin/" \
  "captures/"
write_editorconfig

write_readme "$PROJECT_NAME" "Kotlin Multiplatform app with Compose Multiplatform, Koin DI, and Ktor HTTP client." \
  "./gradlew build" \
  "./gradlew :composeApp:run" \
  "- \`./gradlew build\` - Build all modules
- \`./gradlew :composeApp:run\` - Run desktop app
- \`./gradlew :composeApp:installDebug\` - Install on Android"

finish "./gradlew build" "./gradlew :composeApp:run"
