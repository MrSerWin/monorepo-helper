#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-go-cli" "$@"
create_project_dir

MODULE_NAME="github.com/user/${PROJECT_NAME}"

# --- go.mod ---
write_file "go.mod" "module ${MODULE_NAME}

go 1.23

require (
	github.com/spf13/cobra v1.9.1
	github.com/spf13/viper v1.20.0
)

require (
	github.com/fsnotify/fsnotify v1.8.0 // indirect
	github.com/hashicorp/hcl v1.0.0 // indirect
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/magiconair/properties v1.8.9 // indirect
	github.com/mitchellh/mapstructure v1.5.0 // indirect
	github.com/pelletier/go-toml/v2 v2.2.3 // indirect
	github.com/sagikazarmark/locafero v0.7.0 // indirect
	github.com/sourcegraph/conc v0.3.0 // indirect
	github.com/spf13/afero v1.12.0 // indirect
	github.com/spf13/cast v1.7.1 // indirect
	github.com/spf13/pflag v1.0.6 // indirect
	github.com/subosito/gotenv v1.6.0 // indirect
	go.uber.org/atomic v1.11.0 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	golang.org/x/sys v0.29.0 // indirect
	golang.org/x/text v0.21.0 // indirect
	gopkg.in/ini.v1 v1.67.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)"

# --- main.go ---
write_file "main.go" "package main

import \"${MODULE_NAME}/cmd\"

func main() {
	cmd.Execute()
}"

# --- cmd/root.go ---
write_file "cmd/root.go" 'package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var cfgFile string

var rootCmd = &cobra.Command{
	Use:   "'"$PROJECT_NAME"'",
	Short: "A CLI tool built with Cobra and Viper",
	Long:  `'"$PROJECT_NAME"' is a CLI application scaffolded with Go, Cobra, and Viper.`,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	cobra.OnInitialize(initConfig)
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.'"$PROJECT_NAME"'.yaml)")
}

func initConfig() {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		cobra.CheckErr(err)

		viper.AddConfigPath(home)
		viper.AddConfigPath(".")
		viper.SetConfigType("yaml")
		viper.SetConfigName(".'"$PROJECT_NAME"'")
	}

	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err == nil {
		fmt.Fprintln(os.Stderr, "Using config file:", viper.ConfigFileUsed())
	}
}'

# --- cmd/version.go ---
write_file "cmd/version.go" 'package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the version number",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("'"$PROJECT_NAME"' %s (commit: %s, built: %s)\n", version, commit, date)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}'

# --- cmd/hello.go ---
write_file "cmd/hello.go" 'package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var helloCmd = &cobra.Command{
	Use:   "hello [name]",
	Short: "Say hello to someone",
	Args:  cobra.MaximumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		name := "World"
		if len(args) > 0 {
			name = args[0]
		}

		// Can also read from config
		if viper.IsSet("name") && len(args) == 0 {
			name = viper.GetString("name")
		}

		uppercase, _ := cmd.Flags().GetBool("uppercase")
		message := fmt.Sprintf("Hello, %s!", name)
		if uppercase {
			message = strings.ToUpper(message)
		}
		fmt.Println(message)
	},
}

func init() {
	rootCmd.AddCommand(helloCmd)
	helloCmd.Flags().BoolP("uppercase", "u", false, "Print in uppercase")
}'

# --- internal/config/config.go ---
write_file "internal/config/config.go" 'package config

// Config holds the application configuration
type Config struct {
	Name    string `mapstructure:"name"`
	Verbose bool   `mapstructure:"verbose"`
}

// DefaultConfig returns the default configuration
func DefaultConfig() *Config {
	return &Config{
		Name:    "World",
		Verbose: false,
	}
}'

# --- Makefile ---
write_file_heredoc "Makefile" << 'MAKEFILE'
BINARY_NAME=__PROJECT_NAME__
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "none")
DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS=-ldflags "-X $(shell head -1 go.mod | awk '{print $$2}')/cmd.version=$(VERSION) -X $(shell head -1 go.mod | awk '{print $$2}')/cmd.commit=$(COMMIT) -X $(shell head -1 go.mod | awk '{print $$2}')/cmd.date=$(DATE)"

.PHONY: build run test clean

build:
	go build $(LDFLAGS) -o bin/$(BINARY_NAME) .

run:
	go run . $(ARGS)

test:
	go test ./...

clean:
	rm -rf bin/

install: build
	cp bin/$(BINARY_NAME) $(GOPATH)/bin/
MAKEFILE

# Replace placeholder in Makefile
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/__PROJECT_NAME__/$PROJECT_NAME/g" Makefile
else
  sed -i "s/__PROJECT_NAME__/$PROJECT_NAME/g" Makefile
fi

# --- .goreleaser.yml (optional config) ---
write_file ".goreleaser.yml" 'version: 2
builds:
  - env:
      - CGO_ENABLED=0
    goos:
      - linux
      - darwin
      - windows
    goarch:
      - amd64
      - arm64
    ldflags:
      - -s -w
      - -X {{.ModulePath}}/cmd.version={{.Version}}
      - -X {{.ModulePath}}/cmd.commit={{.ShortCommit}}
      - -X {{.ModulePath}}/cmd.date={{.Date}}

archives:
  - format: tar.gz
    name_template: "{{ .ProjectName }}_{{ .Os }}_{{ .Arch }}"
    format_overrides:
      - goos: windows
        format: zip'

init_git
write_gitignore "bin/" "*.exe"
write_editorconfig

finish "go mod tidy" "go run . hello"
