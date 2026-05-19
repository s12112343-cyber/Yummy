importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCE48KrWhufpijbyieG4-hVubHkeWt0R3Q",
  authDomain: "yummy-d1eb2.firebaseapp.com",
  projectId: "yummy-d1eb2",
  storageBucket: "yummy-d1eb2.firebasestorage.app",
  messagingSenderId: "783921216828",
  appId: "1:783921216828:web:4c6dc62f4281bb1f3ab239",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Background message:", payload);

  const title = payload.notification?.title || "Yummy";
  const body = payload.notification?.body || "";
  const data = payload.data || {};

  self.registration.showNotification(title, {
  body: body,
  icon: "/icons/logo-notification-v2.png",
  badge: "/icons/logo-notification-v2.png",
  data: data,
});
});