/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Handle push notifications from the push_notifications collection
exports.sendPushNotification = functions.firestore
    .document('push_notifications/{notificationId}')
    .onCreate(async (snap, context) => {
        const notification = snap.data();
        
        if (!notification.token) {
            console.error('No FCM token found in notification');
            return null;
        }

        const message = {
            notification: {
                title: notification.title,
                body: notification.body,
            },
            token: notification.token,
            android: {
                notification: {
                    channelId: 'calories_channel',
                    priority: 'high',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };

        try {
            await admin.messaging().send(message);
            console.log('Successfully sent push notification:', notification);
            
            // Delete the push notification document after sending
            await snap.ref.delete();
        } catch (error) {
            console.error('Error sending push notification:', error);
        }
    });

// Keep the existing calorie reminder function for backward compatibility
exports.sendCalorieReminder = functions.firestore
    .document('notifications/{notificationId}')
    .onCreate(async (snap, context) => {
        const notification = snap.data();
        
        if (!notification.token) {
            console.error('No FCM token found in notification');
            return null;
        }

        const message = {
            notification: {
                title: notification.title,
                body: notification.body,
            },
            token: notification.token,
            android: {
                notification: {
                    channelId: 'calories_channel',
                    priority: 'high',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };

        try {
            await admin.messaging().send(message);
            console.log('Successfully sent notification:', notification);
            
            // Delete the notification document after sending
            await snap.ref.delete();
        } catch (error) {
            console.error('Error sending notification:', error);
        }
    });
