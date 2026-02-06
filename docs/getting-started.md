# Getting Started with EasyStreet on Mac

A step-by-step guide for new contributors to clone the repo, set up the development environment, and start working with Claude Code.

---

## Prerequisites

Before you begin, make sure your Mac meets these requirements:

- **macOS 13 (Ventura) or later** recommended
- **8 GB RAM minimum** (16 GB recommended for Android emulator)
- **Admin access** to install developer tools

---

## Step 1: Install Homebrew

Homebrew is the standard package manager for macOS. Open **Terminal** (Cmd + Space, type "Terminal") and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen prompts. When it finishes, it will print instructions to add Homebrew to your PATH. Run those commands, then verify:

```bash
brew --version
```

---

## Step 2: Install Git

macOS includes a version of Git, but install the latest via Homebrew:

```bash
brew install git
```

Configure your identity (use the same email as your GitHub account):

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### Set up SSH keys for GitHub

This is the secure, recommended way to authenticate. Skip this if you already have SSH keys configured.

```bash
# Generate a new SSH key
ssh-keygen -t ed25519 -C "you@example.com"

# Press Enter to accept the default file location
# Set a passphrase when prompted (recommended)

# Start the SSH agent and add your key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy the public key to your clipboard
pbcopy < ~/.ssh/id_ed25519.pub
```

Then add the key to GitHub:

1. Go to **github.com** > **Settings** > **SSH and GPG keys** > **New SSH key**
2. Paste the key from your clipboard
3. Give it a descriptive title (e.g., "MacBook Pro")

Verify the connection:

```bash
ssh -T git@github.com
# Should print: "Hi <username>! You've successfully authenticated..."
```

---

## Step 3: Clone the Repository

```bash
# Navigate to where you want to keep the project
cd ~/Desktop/Apps   # or wherever you prefer
mkdir -p ~/Desktop/Apps && cd ~/Desktop/Apps

# Clone the repo
git clone git@github.com:tshuldberg/EasyStreet.git

# Enter the project directory
cd EasyStreet
```

Verify the clone:

```bash
git status
git log --oneline -5
```

You should see the recent commit history and a clean working tree.

---

## Step 4: Install Xcode (iOS Development)

1. Open the **App Store** and search for **Xcode**
2. Click **Get** / **Install** (this is a large download, ~12 GB)
3. After installation, open Xcode once to accept the license agreement
4. Install command-line tools if prompted:

```bash
xcode-select --install
```

### Open the iOS project

```bash
open EasyStreet/EasyStreet.xcodeproj
```

In Xcode:
1. Select a simulator (e.g., iPhone 15) from the device dropdown
2. Press **Cmd + B** to build
3. Press **Cmd + R** to run
4. Press **Cmd + U** to run tests

If you need to regenerate the Xcode project (e.g., after adding new Swift files):

```bash
brew install xcodegen  # one-time
cd EasyStreet
xcodegen generate
```

---

## Step 5: Install Android Studio (Android Development)

1. Download Android Studio from [developer.android.com/studio](https://developer.android.com/studio)
2. Open the `.dmg` file and drag Android Studio to Applications
3. Launch Android Studio and follow the setup wizard:
   - Choose **Standard** installation type
   - Accept all SDK license agreements
   - Wait for SDK components to download

### Set up the Android SDK path

Add to your shell profile (`~/.zshrc` on modern macOS):

```bash
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools' >> ~/.zshrc
source ~/.zshrc
```

### Configure Google Maps API key

The Android app requires a Google Maps API key. **Never commit this to git.**

1. Get a key from the [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Enable the **Maps SDK for Android** API
3. Create the local gradle properties file:

```bash
echo 'MAPS_API_KEY=your_actual_key_here' >> EasyStreet_Android/local.properties
```

> `local.properties` is already in `.gitignore` so it won't be committed.

### Verify the Android build

```bash
cd EasyStreet_Android
./gradlew assembleDebug
```

---

## Step 6: Install Node.js

Claude Code requires Node.js 18+.

```bash
brew install node
node --version   # Should print v18+ or v20+
```

---

## Step 7: Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

Verify:

```bash
claude --version
```

### First launch

Navigate to the project directory and start Claude Code:

```bash
cd ~/Desktop/Apps/EasyStreet
claude
```

On first run, Claude Code will:
1. Prompt you to log in to your Anthropic account (or use an API key)
2. Detect the project's `.claude/CLAUDE.md` file automatically
3. Load the project instructions and context

---

## Step 8: Understand the Project Structure

Before making changes, familiarize yourself with the codebase:

```
EasyStreet/
├── .claude/
│   └── CLAUDE.md              # Project instructions for Claude Code (read this!)
├── docs/
│   └── plans/                 # Design docs and implementation plans
├── EasyStreet/                # iOS app (Swift + UIKit)
│   ├── Models/                # Data models
│   ├── Controllers/           # View controllers
│   ├── Utils/                 # Business logic
│   └── *.csv                  # Street sweeping dataset (37K rows)
├── EasyStreet_Android/        # Android app (Kotlin + Compose)
│   └── app/
├── timeline.md                # Development history (read this first!)
└── README.md                  # Project overview
```

**Start by reading these files in order:**

1. `README.md` -- project overview
2. `timeline.md` -- what has been done, what's next
3. `.claude/CLAUDE.md` -- detailed architecture and conventions

---

## Best Practices for Working with Claude Code

### Start every session right

1. **Read the timeline first.** Before writing any code, tell Claude:
   ```
   Read timeline.md and tell me the current project status and what's next.
   ```
   This gives Claude full context on recent work and avoids duplicating effort.

2. **Work on a feature branch.** Never commit directly to `master` or `main`:
   ```
   Create a new branch called feature/holiday-calculator and switch to it.
   ```

3. **State your goal clearly.** Be specific about what you want to accomplish:
   ```
   # Good
   Implement Task 4 from the Android implementation plan: HolidayCalculator
   with dynamic holiday computation and 8 unit tests.

   # Too vague
   Work on the Android app.
   ```

### Write code safely

4. **Let Claude read before it writes.** If you ask Claude to modify a file, make sure it reads the file first. It will do this automatically, but if you notice it guessing at file contents, say:
   ```
   Read the file first before making changes.
   ```

5. **Ask for a plan on larger tasks.** For anything touching more than 2-3 files:
   ```
   Plan out how you would implement the SQLite database layer before writing code.
   ```
   Claude will enter plan mode, explore the codebase, and present an approach for your approval.

6. **Review diffs before committing.** Always check what changed:
   ```
   Show me a git diff of all changes before committing.
   ```

7. **Run tests after changes.** Ask Claude to verify its work:
   ```
   Run the tests to make sure nothing is broken.
   ```

### Keep the project organized

8. **Update the timeline.** After every session with meaningful work, tell Claude:
   ```
   Update timeline.md with what we did this session.
   ```
   This is a project requirement documented in `CLAUDE.md`.

9. **Follow the commit message format.** The project uses:
   ```
   Category: Brief description
   ```
   Examples: `feat(android): add HolidayCalculator`, `fix(ios): update hardcoded holidays`

10. **Don't commit secrets.** API keys, keystores, and `local.properties` are in `.gitignore` for a reason. If Claude tries to commit sensitive files, decline and tell it why.

### Use Claude Code effectively

11. **Use slash commands.** Type `/` to see available commands:
    - `/help` -- get help with Claude Code features
    - `/clear` -- clear conversation context when switching tasks

12. **Be direct about mistakes.** If Claude does something wrong, say so plainly:
    ```
    That's not right. The function should return a List, not a Set.
    Revert that change and try again.
    ```

13. **Break large tasks into steps.** Instead of asking Claude to build an entire feature at once, work incrementally:
    ```
    Step 1: Write the data model.
    Step 2: Write the tests.
    Step 3: Write the implementation.
    Step 4: Run the tests and fix any failures.
    ```

14. **Use Claude for code review.** After finishing a feature:
    ```
    Review the changes on this branch against the implementation plan
    and flag anything that doesn't match.
    ```

---

## Quick Reference

### Common commands

| Task | Command |
|------|---------|
| Start Claude Code | `claude` (from project root) |
| Build iOS | Cmd + B in Xcode |
| Run iOS | Cmd + R in Xcode |
| Test iOS | Cmd + U in Xcode |
| Build Android | `cd EasyStreet_Android && ./gradlew assembleDebug` |
| Test Android | `cd EasyStreet_Android && ./gradlew test` |
| Check git status | `git status` |
| View recent history | `git log --oneline -10` |

### Key files

| File | Purpose |
|------|---------|
| `.claude/CLAUDE.md` | Project rules and architecture |
| `timeline.md` | Development history and next steps |
| `docs/plans/2026-02-04-android-implementation-plan.md` | 14-task Android build plan |
| `docs/plans/2026-02-04-android-feature-parity-design.md` | Android architecture design doc |
| `EasyStreet/Utils/SweepingRuleEngine.swift` | iOS business logic (has known bugs) |
| `EasyStreet_Android/app/build.gradle.kts` | Android dependencies |

---

## Troubleshooting

### "xcrun: error: invalid active developer path"
Install Xcode command-line tools:
```bash
xcode-select --install
```

### Gradle build fails with "SDK location not found"
Create `local.properties` in the Android project:
```bash
echo "sdk.dir=$HOME/Library/Android/sdk" > EasyStreet_Android/local.properties
```

### "Permission denied" running gradlew
Make the wrapper executable:
```bash
chmod +x EasyStreet_Android/gradlew
```

### Claude Code says "not authenticated"
Run `claude` and follow the login prompts. You need either:
- An Anthropic account with a Claude Pro/Team subscription, or
- An API key set via `export ANTHROPIC_API_KEY=your_key`

### Git push rejected
You likely need to be added as a collaborator on the GitHub repo. Ask the repo owner for access.
