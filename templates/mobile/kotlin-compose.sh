#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-compose-app" "$@"
create_project_dir

# Convert project name to valid package/class names
PACKAGE_NAME="${PROJECT_NAME//\-/}"
PACKAGE_NAME="${PACKAGE_NAME,,}"
CLASS_NAME="$(echo "$PROJECT_NAME" | sed -E 's/(^|-)([a-z])/\U\2/g')"

# --- settings.gradle.kts ---
write_file "settings.gradle.kts" 'pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "'"$PROJECT_NAME"'"
include(":app")'

# --- gradle.properties ---
write_file "gradle.properties" 'org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
org.gradle.configuration-cache=true'

# --- build.gradle.kts (project) ---
write_file "build.gradle.kts" 'plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.hilt) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}'

# --- gradle/libs.versions.toml ---
write_file "gradle/libs.versions.toml" '[versions]
agp = "8.8.0"
kotlin = "2.1.0"
ksp = "2.1.0-1.0.29"
compose-bom = "2024.12.01"
activity-compose = "1.9.3"
lifecycle = "2.8.7"
navigation = "2.8.5"
hilt = "2.53.1"
hilt-navigation = "1.2.0"
room = "2.6.1"
ktor = "3.0.3"
coroutines = "1.9.0"
serialization = "1.7.3"

[libraries]
# Compose
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-ui-graphics = { group = "androidx.compose.ui", name = "ui-graphics" }
compose-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-icons-extended = { group = "androidx.compose.material", name = "material-icons-extended" }

# Activity & Lifecycle
activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activity-compose" }
lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }
lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycle" }

# Navigation
navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigation" }

# Hilt
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-compiler", version.ref = "hilt" }
hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version.ref = "hilt-navigation" }

# Room
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }

# Ktor
ktor-client-core = { group = "io.ktor", name = "ktor-client-core", version.ref = "ktor" }
ktor-client-android = { group = "io.ktor", name = "ktor-client-android", version.ref = "ktor" }
ktor-client-content-negotiation = { group = "io.ktor", name = "ktor-client-content-negotiation", version.ref = "ktor" }
ktor-serialization-json = { group = "io.ktor", name = "ktor-serialization-kotlinx-json", version.ref = "ktor" }

# Coroutines
coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }

# Serialization
serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "serialization" }

# Testing
junit = { group = "junit", name = "junit", version = "4.13.2" }
compose-ui-test = { group = "androidx.compose.ui", name = "ui-test-junit4" }
compose-ui-test-manifest = { group = "androidx.compose.ui", name = "ui-test-manifest" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }'

# --- gradle/wrapper/gradle-wrapper.properties ---
write_file "gradle/wrapper/gradle-wrapper.properties" 'distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists'

# --- app/build.gradle.kts ---
write_file "app/build.gradle.kts" 'plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.example.'"$PACKAGE_NAME"'"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.'"$PACKAGE_NAME"'"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    // Compose BOM
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.icons.extended)
    debugImplementation(libs.compose.ui.tooling)

    // Activity & Lifecycle
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.lifecycle.viewmodel.compose)

    // Navigation
    implementation(libs.navigation.compose)

    // Hilt
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    // Room
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)

    // Ktor
    implementation(libs.ktor.client.core)
    implementation(libs.ktor.client.android)
    implementation(libs.ktor.client.content.negotiation)
    implementation(libs.ktor.serialization.json)

    // Coroutines
    implementation(libs.coroutines.android)

    // Serialization
    implementation(libs.serialization.json)

    // Testing
    testImplementation(libs.junit)
    androidTestImplementation(composeBom)
    androidTestImplementation(libs.compose.ui.test)
    debugImplementation(libs.compose.ui.test.manifest)
}'

# --- app/proguard-rules.pro ---
write_file "app/proguard-rules.pro" '# Add project specific ProGuard rules here.'

# --- app/src/main/AndroidManifest.xml ---
write_file "app/src/main/AndroidManifest.xml" '<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:name=".'"$CLASS_NAME"'Application"
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.'"$CLASS_NAME"'">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.'"$CLASS_NAME"'">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>'

# --- app/src/main/res/values/strings.xml ---
write_file "app/src/main/res/values/strings.xml" '<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">'"$CLASS_NAME"'</string>
</resources>'

# --- app/src/main/res/values/themes.xml ---
write_file "app/src/main/res/values/themes.xml" '<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.'"$CLASS_NAME"'" parent="android:Theme.Material.Light.NoActionBar" />
</resources>'

# --- Application class ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/${CLASS_NAME}Application.kt" 'package com.example.'"$PACKAGE_NAME"'

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class '"$CLASS_NAME"'Application : Application()'

# --- MainActivity ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/MainActivity.kt" 'package com.example.'"$PACKAGE_NAME"'

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dagger.hilt.android.AndroidEntryPoint
import com.example.'"$PACKAGE_NAME"'.ui.theme.AppTheme
import com.example.'"$PACKAGE_NAME"'.ui.navigation.AppNavigation

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AppTheme {
                AppNavigation()
            }
        }
    }
}'

# --- Theme ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/ui/theme/AppTheme.kt" 'package com.example.'"$PACKAGE_NAME"'.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context)
            else dynamicLightColorScheme(context)
        }
        darkTheme -> darkColorScheme()
        else -> lightColorScheme()
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography(),
        content = content,
    )
}'

# --- Navigation ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/ui/navigation/AppNavigation.kt" 'package com.example.'"$PACKAGE_NAME"'.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.'"$PACKAGE_NAME"'.ui.screens.home.HomeScreen
import com.example.'"$PACKAGE_NAME"'.ui.screens.details.DetailsScreen

@Composable
fun AppNavigation() {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = "home") {
        composable("home") {
            HomeScreen(
                onNavigateToDetails = { id ->
                    navController.navigate("details/$id")
                },
            )
        }
        composable("details/{itemId}") { backStackEntry ->
            val itemId = backStackEntry.arguments?.getString("itemId")?.toLongOrNull() ?: 0L
            DetailsScreen(
                itemId = itemId,
                onNavigateBack = { navController.popBackStack() },
            )
        }
    }
}'

# --- HomeScreen ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/ui/screens/home/HomeScreen.kt" 'package com.example.'"$PACKAGE_NAME"'.ui.screens.home

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.'"$PACKAGE_NAME"'.data.local.NoteEntity

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onNavigateToDetails: (Long) -> Unit,
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val notes by viewModel.notes.collectAsState(initial = emptyList())

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Notes") })
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { viewModel.addNote() }) {
                Icon(Icons.Default.Add, contentDescription = "Add note")
            }
        },
    ) { padding ->
        if (notes.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                Text("No notes yet. Tap + to add one.")
            }
        } else {
            LazyColumn(
                modifier = Modifier.padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(notes, key = { it.id }) { note ->
                    NoteCard(note = note, onClick = { onNavigateToDetails(note.id) })
                }
            }
        }
    }
}

@Composable
private fun NoteCard(note: NoteEntity, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = note.title,
                style = MaterialTheme.typography.titleMedium,
            )
            if (note.content.isNotEmpty()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = note.content,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 2,
                )
            }
        }
    }
}'

# --- HomeViewModel ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/ui/screens/home/HomeViewModel.kt" 'package com.example.'"$PACKAGE_NAME"'.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.'"$PACKAGE_NAME"'.data.local.NoteEntity
import com.example.'"$PACKAGE_NAME"'.data.repository.NoteRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val repository: NoteRepository,
) : ViewModel() {

    val notes: Flow<List<NoteEntity>> = repository.getAllNotes()

    fun addNote() {
        viewModelScope.launch {
            val count = repository.getCount()
            repository.insertNote(
                NoteEntity(
                    title = "Note ${count + 1}",
                    content = "This is note number ${count + 1}.",
                )
            )
        }
    }
}'

# --- DetailsScreen ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/ui/screens/details/DetailsScreen.kt" 'package com.example.'"$PACKAGE_NAME"'.ui.screens.details

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailsScreen(
    itemId: Long,
    onNavigateBack: () -> Unit,
    viewModel: DetailsViewModel = hiltViewModel(),
) {
    val note by viewModel.getNote(itemId).collectAsState(initial = null)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(note?.title ?: "Details") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = {
                        viewModel.deleteNote(itemId)
                        onNavigateBack()
                    }) {
                        Icon(Icons.Default.Delete, contentDescription = "Delete")
                    }
                },
            )
        },
    ) { padding ->
        note?.let { n ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(16.dp),
            ) {
                Text(
                    text = n.title,
                    style = MaterialTheme.typography.headlineMedium,
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = n.content,
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        } ?: Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator()
        }
    }
}'

# --- DetailsViewModel ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/ui/screens/details/DetailsViewModel.kt" 'package com.example.'"$PACKAGE_NAME"'.ui.screens.details

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.'"$PACKAGE_NAME"'.data.local.NoteEntity
import com.example.'"$PACKAGE_NAME"'.data.repository.NoteRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class DetailsViewModel @Inject constructor(
    private val repository: NoteRepository,
) : ViewModel() {

    fun getNote(id: Long): Flow<NoteEntity?> = repository.getNoteById(id)

    fun deleteNote(id: Long) {
        viewModelScope.launch {
            repository.deleteNoteById(id)
        }
    }
}'

# --- Room Database ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/data/local/NoteEntity.kt" 'package com.example.'"$PACKAGE_NAME"'.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "notes")
data class NoteEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val title: String,
    val content: String,
    val createdAt: Long = System.currentTimeMillis(),
)'

write_file "app/src/main/java/com/example/${PACKAGE_NAME}/data/local/NoteDao.kt" 'package com.example.'"$PACKAGE_NAME"'.data.local

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface NoteDao {

    @Query("SELECT * FROM notes ORDER BY createdAt DESC")
    fun getAllNotes(): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE id = :id")
    fun getNoteById(id: Long): Flow<NoteEntity?>

    @Query("SELECT COUNT(*) FROM notes")
    suspend fun getCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertNote(note: NoteEntity)

    @Query("DELETE FROM notes WHERE id = :id")
    suspend fun deleteNoteById(id: Long)
}'

write_file "app/src/main/java/com/example/${PACKAGE_NAME}/data/local/AppDatabase.kt" 'package com.example.'"$PACKAGE_NAME"'.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(entities = [NoteEntity::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun noteDao(): NoteDao
}'

# --- Repository ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/data/repository/NoteRepository.kt" 'package com.example.'"$PACKAGE_NAME"'.data.repository

import com.example.'"$PACKAGE_NAME"'.data.local.NoteDao
import com.example.'"$PACKAGE_NAME"'.data.local.NoteEntity
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NoteRepository @Inject constructor(
    private val noteDao: NoteDao,
) {
    fun getAllNotes(): Flow<List<NoteEntity>> = noteDao.getAllNotes()

    fun getNoteById(id: Long): Flow<NoteEntity?> = noteDao.getNoteById(id)

    suspend fun getCount(): Int = noteDao.getCount()

    suspend fun insertNote(note: NoteEntity) = noteDao.insertNote(note)

    suspend fun deleteNoteById(id: Long) = noteDao.deleteNoteById(id)
}'

# --- Hilt DI Module ---
write_file "app/src/main/java/com/example/${PACKAGE_NAME}/di/AppModule.kt" 'package com.example.'"$PACKAGE_NAME"'.di

import android.content.Context
import androidx.room.Room
import com.example.'"$PACKAGE_NAME"'.data.local.AppDatabase
import com.example.'"$PACKAGE_NAME"'.data.local.NoteDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import io.ktor.client.*
import io.ktor.client.engine.android.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.json.Json
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            "app_database",
        ).build()
    }

    @Provides
    @Singleton
    fun provideNoteDao(database: AppDatabase): NoteDao {
        return database.noteDao()
    }

    @Provides
    @Singleton
    fun provideHttpClient(): HttpClient {
        return HttpClient(Android) {
            install(ContentNegotiation) {
                json(Json {
                    ignoreUnknownKeys = true
                    prettyPrint = true
                })
            }
        }
    }
}'

init_git
write_gitignore "*.iml" ".gradle/" "local.properties" ".idea/" "build/" "captures/" ".externalNativeBuild/" ".cxx/" "*.apk" "*.aab"
write_editorconfig

finish "./gradlew build" "./gradlew installDebug"
