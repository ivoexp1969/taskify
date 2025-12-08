// Firebase Messaging Service Worker
// Този файл ТРЯБВА да е в web/ папката

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDAwis_cnXVpWIMrNzvWAcaOhPVrIJSewE",
  authDomain: "taskify-1969.firebaseapp.com",
  projectId: "taskify-1969",
  storageBucket: "taskify-1969.firebasestorage.app",
  messagingSenderId: "929046134968",
  appId: "1:929046134968:web:5f2754f3d7efee5bc8744d"
});

const messaging = firebase.messaging();

// Background message handler
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  
  const notificationTitle = payload.notification?.title || 'Напомняне';
  const notificationOptions = {
    body: payload.notification?.body || 'Имаш задача за изпълнение',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.taskId || 'task-reminder',
    requireInteraction: true,
    data: payload.data
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification clicked:', event);
  event.notification.close();
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Ако приложението е отворено, фокусирай го
      for (const client of clientList) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      // Ако не е отворено, отвори го
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
