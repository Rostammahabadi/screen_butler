# ScreenButler

ScreenButler is an intelligent file management application for macOS that helps users organize and rename files using AI. It specializes in analyzing screenshots, media files, and documents with ambiguous filenames, and suggests meaningful names based on file content.

## Overview

ScreenButler lives in your menu bar, providing quick access to powerful file organization tools. The app helps solve the common problem of messy file names, especially for screenshots and downloads that often have cryptic, timestamp-based names.

## Key Features

### Smart Selection
- Automatically identifies files with ambiguous or generic names
- Focuses on screenshots, recordings, and downloaded files
- One-click selection of all files that need better names

### AI-Powered Renaming
- Analyzes file content using OpenAI's models
- Generates descriptive, meaningful filenames based on image content, document text, or video content
- Handles batch renaming of multiple files at once

### User-Friendly Interface
- Lives in the menu bar for easy access
- Provides a full file browser interface for navigation
- Allows both quick actions and detailed control over renaming
- Includes filters for managing large batches of files

### File Support
- Images: JPG, JPEG, PNG, HEIC, HEIF, GIF, WEBP, TIFF, RAW, BMP
- Videos: MP4, MOV, M4V, AVI, WMV, WEBM, MKV, 3GP
- Documents: PDF, TXT, RTF, DOC, DOCX, PAGES
- Spreadsheets: XLS, XLSX, CSV, NUMBERS

## Technical Architecture

ScreenButler is built with:
- **SwiftUI**: Modern declarative UI framework
- **OpenAI API**: Powers the content analysis and name generation
- **App Sandbox**: Ensures security for file operations
- **Security-Scoped Bookmarks**: Maintains secure access to user-selected directories

### Core Components
- **FileSystemService**: Handles file browsing, navigation, and permissions
- **OpenAIService**: Manages API communication with OpenAI
- **FileRenameService**: Safely renames files while preserving extensions
- **ContentView**: Main application UI with file browser and selection tools
- **BatchRenameView**: Interface for reviewing and applying AI-suggested names

## Setup and Configuration

### Requirements
- macOS 12.0 or later
- Internet connection for AI features
- OpenAI API key for AI-powered renaming

### Installation
1. Download the latest release from the App Store or TestFlight
2. Launch ScreenButler
3. Enter your OpenAI API key when prompted (or later in settings)
4. Grant permission to access files when requested

### API Key Setup
- Create an account at [OpenAI's website](https://platform.openai.com)
- Generate an API key in your OpenAI dashboard
- Enter the key in ScreenButler's settings
- Your key is stored securely in the macOS keychain

## Usage Guide

### Basic Usage
1. Click the ScreenButler icon in your menu bar
2. Choose "Browse Files" or "Select Directory" 
3. Navigate to the folder containing files you want to organize
4. Use "Smart Select" to automatically find files with ambiguous names
5. Review the AI-suggested names
6. Apply the changes to rename your files

### Smart Rename Directory
1. Click the ScreenButler icon in your menu bar
2. Choose "Smart Rename Directory"
3. Select a folder to analyze
4. ScreenButler will automatically identify and select files for renaming
5. Review and approve the suggested names
6. Apply changes to rename all approved files at once

### Manual Selection
- Use the file browser to navigate to any folder
- Check the boxes next to files you want to rename
- Click "Rename with AI" to generate name suggestions

## Privacy and Security

- ScreenButler uses the App Sandbox to ensure secure file operations
- File access is limited to user-selected directories
- The app only sends minimal information to OpenAI (file content) for analysis
- No user data is stored or shared beyond what's needed for file analysis
- Your API key is stored securely in the macOS keychain

## Support and Feedback

For support, feature requests, or feedback:
- Email: [support@screenbutler.app](mailto:support@screenbutler.app)
- Twitter: [@ScreenButlerApp](https://twitter.com/ScreenButlerApp)
- GitHub: [Report issues](https://github.com/screenbutler/issues)

If you find ScreenButler helpful, consider supporting the developer:
- [Buy Me a Coffee](https://buymeacoffee.com/RostamMahabadi)

## License

ScreenButler is proprietary software. All rights reserved.

---

Made with ❤️ for people who take too many screenshots 