# EasyStreet - Street Sweeping Parking Assistant

EasyStreet is an iOS application designed to help users avoid parking tickets by providing clear, timely, and accurate information about street sweeping schedules in San Francisco.

## Core Features

1. **Interactive Map**: Displays street sweeping schedules on a map with color-coded streets.
2. **Park My Car**: Allows users to mark where they parked and fine-tune the location if needed.
3. **Notifications**: Sends reminders before street sweeping occurs at the parked location.

## Project Structure

```
EasyStreet/
├── Models/
│   ├── StreetSweepingData.swift    # Models for street sweeping data
│   └── ParkedCar.swift             # Model for parked car management
├── Views/
├── Controllers/
│   └── MapViewController.swift     # Main map view controller
├── Utils/
│   └── SweepingRuleEngine.swift    # Core logic for determining sweeping rules
├── Resources/
├── AppDelegate.swift               # App delegate
├── SceneDelegate.swift             # Scene delegate
├── Info.plist                      # App configuration
└── LaunchScreen.storyboard         # Launch screen
```

## Setup for Development

### Prerequisites

- Xcode 12.0+
- iOS 14.0+ device or simulator

### Opening the Project

1. Create an Xcode project with the provided files
2. Ensure the files are organized according to the structure above
3. Set the organization identifier to your preferred bundle ID (e.g., com.yourdomain.easystreet)

### Required Permissions

The app requires the following permissions:

- Location (to determine your current position and where you parked)
- Notifications (to send sweeping alerts)

## Transferring to Mac

If you're transferring this project from Windows to Mac:

1. Create a new Xcode project on Mac
2. Drag and drop the Swift files into the appropriate groups in your Xcode project
3. Make sure to set the correct target membership for each file
4. Update the Info.plist with the required keys and values
5. Set up the LaunchScreen.storyboard in the Interface Builder

## Notes for Visual UI Testing

For the MVP UI testing:

1. The app uses sample data (Market St. and Mission St.) with mock sweeping rules
2. The "I Parked Here" button will use your current location and show sweeping info
3. You can long-press and drag the parked car marker to fine-tune its position
4. The status view will show different colors based on sweeping proximity
5. Street sweeping schedules are color-coded on the map (red = today, green = safe)

## Next Steps (Post MVP)

- Implement the data parsing script for actual SF street sweeping data
- Add advanced notification features with customizable lead times
- Implement more granular color coding based on sweeping proximity
- Add the "Where Can I Park?" advisor feature for suggesting safe parking zones 