# PantryPal

**Track Freshness. Reduce Waste.**

PantryPal is a Flutter mobile app for household food expiry and pantry management. It helps people keep a record of what they have at home, see which items are still fresh, plan what to buy, and note food that was wasted.

The app is published as the Flutter package `food_expiry_and_pantry_management` (version `1.0.0+1`). The in-app name is **PantryPal**.

## About the Project

Household food is easy to forget until it expires. PantryPal gives a signed-in user one place to:

- store pantry items in Cloud Firestore
- see expiry status from each item’s date
- keep a shopping list, including items that run low
- record wasted food and review it by day, week, or month
- browse a local recipe catalogue and match it against pantry ingredients

Pantry items, shopping items, and waste records belong to the signed-in user. Shared pantry support covers household membership and invite codes. It does not yet store one shared inventory for every member.

## Key Features

### Pantry management

Implemented against `users/{uid}/pantryItems`:

- Add, edit, view, and permanently delete items
- Fields: name, category, storage location, quantity, unit, price (shown as Rs.), and an optional expiry date
- Categories: Dairy, Meat, Grains, Fruits, Vegetables, Beverages, Snacks, Condiments, Other
- Locations: Refrigerator, Freezer, Pantry
- Units: items, kg, g, L, ml, packs, bottles
- Search by name, category, or location
- Filters for category, location, and stock level, plus sort by recently added or name
- Dashboard preview of five recent items, with **View All** opening the full list
- Card and list layouts on the full list
- Duplicate-name check before save (trimmed, case-insensitive)
- Low-stock indicator when quantity is at or below the unit threshold (100 for g and ml, otherwise 1)
- Quantity steppers, with undo after a successful update
- **Mark consumed**, which subtracts a chosen amount and can leave an item at zero
- **Used Up**, which deletes the document and can restore it with **Undo**

The Pantry screen is the live Firestore path. `lib/features/pantry/data/repositories/mock_pantry_repository.dart` is not what that screen reads.

### Expiry management

- Status is calculated from the expiry date: **Fresh**, **Expiring soon** (within 3 days), **Expired**, or **Unknown**
- The Expiry screen summarises those counts and lists items that need attention
- Opening Expiry writes matching alert documents to the `expiry_alerts` collection for the signed-in user
- Home shows a live count of items expiring soon

The Expiry Notifications screen lets the user toggle alert types, days before expiry, time, and frequency. Those choices stay in widget state. Saving shows a confirmation and does not persist the settings or schedule device notifications. The project does not include a push or local-notification package.

### Shopping list

The Shop tab uses `users/{uid}/shopping_items`:

- Add, edit, and delete items
- Quantity from 1 to 100
- Mark items as bought or still to buy
- Search, and filter by All, To buy, and Bought
- Group items with a built-in food-name catalogue
- Multi-select delete
- Name suggestions while adding an item
- Low-stock pantry items are added to the list automatically while the app is running

`lib/features/shopping/` is an earlier in-memory shopping module. It is not registered in the router. The Shop tab is `ShoppingListScreen`.

### Food waste tracking

Opened from the Home waste summary, at `/waste-tracker`, and stored in `users/{uid}/waste_records`:

- Record, edit, and delete waste entries
- Quantity, unit, reason (Expired, Spoiled, Not Used, Cooked Too Much, Other), estimated value, and date
- Summaries for today, this week, and this month, compared with the previous period
- History view
- Record waste from expired pantry items

### Recipes

The Recipes tab is implemented and reads a local seed list from `MockRecipeRepository`, not Firestore:

- Search, category filters, and an in-memory favourites toggle
- Recipe details with ingredients and instructions
- Rule-based suggestions from current pantry items, with extra weight for ingredients expiring within 3 or 7 days
- Add missing ingredients to the Firestore shopping list

Favourites reset when the app process ends. The Home “Recipe suggestions” card shows the fixed label **8 Ready**; it is not the live recommendation count.

### Account, profile, and shared pantry

- Email and password sign-up and sign-in with Firebase Authentication
- Password reset email
- User profile document in `users/{uid}` (name, email, pantry type, timestamps)
- Profile editing, pantry type (personal, family, or shared), password change, and sign-out
- Create a shared pantry, join with a 6-character invite code, copy or share the code, view members, and leave
- A user can belong to one shared pantry at a time

### Theme

Light, dark, and system themes. The choice is stored with `shared_preferences`.

## Technology Stack

| Area | Used in this project |
| --- | --- |
| UI | Flutter, Material 3 |
| Language | Dart (`>=3.11.0 <4.0.0`) |
| State | Riverpod (`flutter_riverpod`) |
| Navigation | `go_router` |
| Backend | Firebase Core, Firebase Authentication, Cloud Firestore |
| Local preference | `shared_preferences` (theme mode) |
| Sharing | `share_plus` (shared-pantry invite code) |
| Icons | `cupertino_icons` and Material icons |

Barcode scanning, image upload, and device notifications are not dependencies of this project.

## Project Structure

```text
food_expiry_and_pantry_management/
├── android/                         # Android runner; includes google-services.json
├── ios/                             # iOS runner
├── assets/images/                   # Splash logo and onboarding artwork
├── lib/
│   ├── main.dart                    # Firebase init, SharedPreferences, ProviderScope
│   ├── app.dart                     # MaterialApp.router, theme, low-stock sync host
│   ├── firebase_options.dart        # FlutterFire options (do not publish extra copies of keys)
│   ├── core/
│   │   ├── constants/               # App name, copy, FreshPalette and status colours
│   │   ├── providers/               # Theme mode and current user name
│   │   ├── router/                  # go_router routes
│   │   ├── services/                # AuthService
│   │   └── theme/                   # Light and dark ThemeData
│   └── features/
│       ├── splash/
│       ├── onboarding/
│       ├── Authentication/          # Login and sign-up
│       ├── home/
│       ├── pantry/
│       ├── expiry/
│       ├── shopping_list/           # Routed shopping list
│       ├── shopping/                # Unused in-memory shopping module
│       ├── recipes/
│       ├── food_waste_tracking/
│       ├── shared_pantry/
│       ├── profile/
│       └── settings/
├── test/
├── firebase.json
├── firestore.rules
├── firestore.indexes.json
└── pubspec.yaml
```

`lib/core` holds app-wide routing, theme, and authentication. Each feature under `lib/features` keeps its own screens, widgets, models, and data access. Pantry, expiry, shopping, recipes, and waste follow a presentation / domain / data split where that code exists. Windows, macOS, and Linux runner folders are also present. Linux is not configured in `DefaultFirebaseOptions`.

## App Navigation

Startup goes to `/splash`, then `/onboarding`, then `/login`. Sign-in opens `/home`. Splash does not check for an existing Firebase session, so onboarding is shown on every cold start.

The main shell has a bottom bar:

| Tab | Route | Screen |
| --- | --- | --- |
| Home | `/home` | Overview cards for pantry, expiry, shopping, waste, and recipes |
| Pantry | `/pantry` | Recent items; `/pantry/items` is View All |
| Expiry | `/expiry` | Expiry monitoring; `/expiry/notifications` is the settings form |
| Shop | `/shopping` | Shopping list; `/shopping/add` adds or edits an item |
| Recipes | `/recipes` | Local recipe catalogue |
| Settings | `/settings` | Profile summary, notification screen link, theme |

Other routes:

- `/signup`
- `/profile` and `/change-password`
- `/shared-pantry` and `/shared-pantry-members`
- `/waste-tracker`

Pantry add, edit, and item details are pushed with `Navigator`, not `go_router`. Waste record and history screens are pushed the same way.

## Theme

The UI uses Material 3 and the **FreshPalette** colours in `lib/core/constants/app_colors.dart`.

| Role | Light |
| --- | --- |
| Primary button | `#174A3A` |
| Selected | `#2E6B4E` |
| Highlight | `#B8D98A` |
| Page background | `#F5F7F2` |
| Heading | `#17201B` |
| Secondary text | `#6B7280` |
| Card | `#FFFFFF` |

Dark mode uses the same green identity on `#101714` page background and `#1C2621` cards. Expiry status uses green for fresh, orange for expiring soon, and red for expired. Layouts use flexible rows, `Expanded`, and scroll views rather than a separate breakpoint system.

## Getting Started

### Prerequisites

- Flutter SDK that satisfies Dart `>=3.11.0 <4.0.0`
- A device or emulator (Android is the platform with `google-services.json` in the repo)
- Android Studio or VS Code with the Flutter plugin
- A Firebase project with **Authentication (Email/Password)** and **Cloud Firestore** enabled

### Installation

```bash
git clone https://github.com/AaishaShahani2001/IT3060HCI2026_Food_Expiry_and_Pantry_Management_WE_45.git
cd IT3060HCI2026_Food_Expiry_and_Pantry_Management_WE_45
flutter pub get
```

### Firebase setup

Firebase is initialised in `lib/main.dart` with `lib/firebase_options.dart`.

Already in the repository:

- FlutterFire options for Android, iOS, macOS, web, and Windows
- Android config at `android/app/google-services.json`
- `firebase.json` and `firestore.rules`

The committed Firestore rules allow any signed-in user to read and write every document. That is enough for local development. Tighten the rules before any wider release.

To point the app at a different Firebase project, regenerate platform files with the FlutterFire CLI and do not paste API keys into this README or into chat:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Enable Email/Password sign-in in the Firebase console before creating an account. Linux builds are not supported by the current `DefaultFirebaseOptions`.

### Run

```bash
flutter pub get
flutter run
```

Create an account on the sign-up screen, then use the same email and password on the login screen. Pantry, shopping, and waste data are stored for that Firebase user.

Widget and unit tests live under `test/`:

```bash
flutter test
```

## Screenshots

Screenshots are not stored in this repository yet. Add them here when they are available, for example:

```text
docs/screenshots/home.png
docs/screenshots/pantry.png
docs/screenshots/expiry.png
docs/screenshots/shopping.png
```

`assets/images/` currently holds the splash logo (`HCI_LOGO.png`) and three onboarding illustrations. Those are not screen captures of the running app.

## Project Status

**Implemented**

- Splash, three-page onboarding, email sign-up, sign-in, and password reset
- Profile update, password change, sign-out, and theme preference
- Firestore pantry CRUD, search, filters, sort, card/list layouts, duplicates, low stock, consume, Used Up, and undo
- Expiry status, in-app alerts stored in Firestore, and the Expiry screen
- Firestore shopping list, purchased state, catalogue grouping, and low-stock sync
- Firestore waste records, period summaries, and recording waste from expired pantry items
- Local recipe list, pantry-based recommendations, and “add missing ingredients”
- Shared pantry create, join, invite, members, and leave

**Partial**

- Expiry notification settings are a form only. They are not saved and do not send notifications
- Home shopping and recipe overview values are fixed labels (`5 Needed`, `8 Ready`)
- Recipe data and favourites live in memory for the session
- Shared pantry manages members, not a shared item list
- Splash always opens onboarding, including for a user who is already signed in
- `lib/features/shopping/` is not connected to navigation

**Not included**

- Barcode scanning
- Item photos
- Scheduled or push notifications

## Academic Context

This application was developed as an HCI academic project.

## Contributors

Git history records these authors:

- A A. Aaisha Shahani
- Thisara Sandapium
- mjaankishna
- Pireethi
- pireethika-r

## License

This repository does not include a license file. It is intended for academic and educational use.
