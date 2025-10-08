importScripts('https://www.gstatic.com/firebasejs/12.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.0.0/firebase-messaging-compat.js');

// --- Initialize Firebase ---
firebase.initializeApp({
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID"
});

const messaging = firebase.messaging();

// Background message handler
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Background message received:', payload);

  const notificationTitle = payload.notification?.title || 'Hostel Gate Pass';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new notification',
    icon: '/icons/favicon.png',
    vibrate: [200, 100, 200], // optional vibration
    // Add more options like badge, sound if needed
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
