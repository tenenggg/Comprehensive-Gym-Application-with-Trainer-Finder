# Notification System Documentation

## Overview

The notification system provides a comprehensive solution for handling notifications for both users and trainers in the GT Finder app. It includes real-time notifications, push notifications, and a dedicated notification management interface.

## Features

### 1. Notification Types
- **Booking Request**: When a user requests to book a trainer
- **Booking Confirmed**: When a trainer confirms a booking
- **Booking Cancelled**: When a booking is cancelled
- **Payment Received**: When a trainer receives payment
- **Calorie Reminder**: Daily calorie goal reminders
- **Exercise Reminder**: Exercise schedule reminders
- **General**: General notifications

### 2. Notification Status
- **Unread**: New notifications that haven't been viewed
- **Read**: Notifications that have been viewed

### 3. Notification Management
- View all notifications in a dedicated tab
- Mark individual notifications as read
- Mark all notifications as read
- Delete notifications
- Real-time notification count badges

## Architecture

### 1. Models
- `NotificationModel`: Defines the structure of notifications
- `NotificationType`: Enum for different notification types
- `NotificationStatus`: Enum for notification status

### 2. Services
- `NotificationService`: Handles all notification operations
  - Create notifications
  - Send push notifications
  - Mark notifications as read/unread
  - Get notification counts
  - Delete notifications

### 3. Pages
- `NotificationPage`: User notification interface
- `TrainerNotificationPage`: Trainer notification interface

### 4. Widgets
- `NotificationBadge`: Shows unread notification count

## Database Structure

### Collections

#### `notifications`
```json
{
  "id": "notification_id",
  "userId": "user_or_trainer_id",
  "title": "Notification Title",
  "body": "Notification Body",
  "type": "bookingRequest|bookingConfirmed|bookingCancelled|paymentReceived|calorieReminder|exerciseReminder|general",
  "status": "unread|read",
  "timestamp": "timestamp",
  "data": {
    "additional_data": "value"
  },
  "senderId": "sender_user_id",
  "senderName": "Sender Name"
}
```

#### `push_notifications`
```json
{
  "token": "fcm_token",
  "title": "Push Notification Title",
  "body": "Push Notification Body",
  "timestamp": "timestamp"
}
```

## Implementation Details

### 1. Creating Notifications

```dart
// Create a general notification
await notificationService.createNotification(
  userId: userId,
  title: 'Notification Title',
  body: 'Notification Body',
  type: NotificationType.general,
);

// Create a booking request notification
await notificationService.createBookingRequestNotification(
  trainerId: trainerId,
  trainerName: trainerName,
  userId: userId,
  userName: userName,
);
```

### 2. Displaying Notifications

```dart
// Stream notifications
StreamBuilder<List<NotificationModel>>(
  stream: notificationService.getUserNotifications(userId),
  builder: (context, snapshot) {
    // Build notification list
  },
)
```

### 3. Notification Badge

```dart
NotificationBadge(
  child: Icon(Icons.notifications),
  userId: currentUserId,
)
```

## Firebase Functions

### 1. `sendPushNotification`
- Triggers when a document is created in `push_notifications` collection
- Sends FCM push notification to the specified token
- Deletes the push notification document after sending

### 2. `sendCalorieReminder` (Legacy)
- Maintained for backward compatibility
- Handles the old notification structure

## Integration Points

### 1. Booking System
- Creates notifications when users book trainers
- Creates notifications when bookings are confirmed/cancelled

### 2. Payment System
- Creates notifications when payments are completed
- Notifies both users and trainers

### 3. Calorie Tracking
- Creates daily reminder notifications
- Integrates with existing calorie goal system

## Usage Examples

### 1. Adding Notification Tab
The notification tab has been added to both user and trainer landing pages:

```dart
_buildActionCard(
  context,
  'Notifications',
  Icons.notifications,
  () => _navigateToPage(const NotificationPage()),
),
```

### 2. Creating Notifications from Events
```dart
// When a user books a trainer
await notificationService.createBookingRequestNotification(
  trainerId: trainerId,
  trainerName: trainerName,
  userId: userId,
  userName: userName,
);

// When payment is completed
await notificationService.createPaymentReceivedNotification(
  trainerId: trainerId,
  userName: userName,
  amount: amount,
);
```

### 3. Testing Notifications
Both notification pages include a floating action button to create test notifications for development and testing purposes.

## Security Rules

Ensure your Firestore security rules allow:
- Users to read their own notifications
- Users to update notification status
- Users to delete their own notifications
- System to create notifications for users

## Future Enhancements

1. **Notification Preferences**: Allow users to customize which notifications they receive
2. **Notification Scheduling**: Schedule notifications for specific times
3. **Rich Notifications**: Support for images and actions in notifications
4. **Notification History**: Archive old notifications
5. **Bulk Actions**: Select and manage multiple notifications at once

## Troubleshooting

### Common Issues

1. **Notifications not appearing**: Check FCM token is properly saved
2. **Push notifications not working**: Verify Firebase Functions are deployed
3. **Badge count not updating**: Ensure notification status is properly updated

### Debug Steps

1. Check Firestore for notification documents
2. Verify FCM tokens are saved in user documents
3. Check Firebase Functions logs for errors
4. Test with the built-in test notification feature 