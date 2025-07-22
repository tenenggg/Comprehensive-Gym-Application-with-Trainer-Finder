# GTFinder

GTFinder is a comprehensive Flutter-based mobile application designed to bridge the gap between fitness enthusiasts, professional trainers, and gym facilities. The app provides a seamless platform for users to discover gyms, connect with personal trainers, and manage their fitness journey. For trainers, it offers tools to manage clients, schedules, and payments. Admin users have access to a powerful dashboard to oversee the entire ecosystem.

## Features

### For Users
- **Gym Finder**: Locate nearby gyms using an interactive map. View details, and get directions.
- **Trainer Finder**: Browse and connect with certified personal trainers.
- **Booking System**: Schedule and manage sessions with trainers.
- **Calorie Tracking**: Monitor daily calorie intake and expenditure.
- **Payment System**: Securely pay for trainer sessions and gym memberships.
- **User Profile**: Manage personal information and view booking history.

### For Trainers
- **Client Management**: Keep track of clients and their progress.
- **Schedule Management**: Set availability and manage bookings.
- **Payment Processing**: Receive payments from clients securely.
- **Profile Management**: Showcase skills, certifications, and experience to attract clients.

### For Admins
- **Dashboard**: A comprehensive overview of the app's activity, including user and trainer statistics.
- **User Management**: View and manage all users and trainers on the platform.
- **Settings**: Configure application settings and manage content.

## Tech Stack

- **Frontend**: Flutter
- **Backend**: Firebase (Authentication, Firestore, Storage, Cloud Functions)
- **Maps**: Google Maps, Mapbox
- **Payments**: Stripe
- **State Management**: Provider, RxDart
- **HTTP Client**: Dio, http
- **Local Notifications**: flutter_local_notifications

## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

- Flutter SDK: [Installation Guide](https://flutter.dev/docs/get-started/install)
- Firebase Account: [Create a Firebase project](https://firebase.google.com/)      
- Youtube Presentation: [Presentation Video](https://www.youtube.com/watch?v=LwAfs2OLS-w) 

### Installation

1. **Clone the repo**
   ```sh
   git clone https://github.com/your_username/gtfinder.git
   ```
2. **Navigate to the project directory**
   ```sh
   cd gtfinder
   ```
3. **Install NPM packages for backend**
   ```sh
   cd backend && npm install && cd ..
   ```
4. **Install NPM packages for functions**
   ```sh
   cd functions && npm install && cd ..
   ```
5. **Install Flutter packages**
   ```sh
   flutter pub get
   ```
6. **Set up Firebase**
   - Follow the instructions to add a new Android and/or iOS app to your Firebase project.
   - Download the `google-services.json` file for Android and place it in `android/app/`.
   - For iOS, download `GoogleService-Info.plist` and add it to your project in Xcode.

7. **Set up environment variables**
   - Create a `.env` file in the root of the project.
   - Add your API keys for Google Maps, Mapbox, and other services to the `.env` file.

8. **Run the app**
   ```sh
   flutter run
   ```

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

