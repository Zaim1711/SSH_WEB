// firebase-messaging-sw.js
// importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app.js');
// importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging.js');

// firebase.initializeApp({
//     apiKey: "AIzaSyCo8JAAj1VfDVY_BaTnj71GIKuhJpX9NiU",
//     authDomain: "sshchatfitur.firebaseapp.com",
//     projectId: "sshchatfitur",
//     storageBucket: "sshchatfitur.firebasestorage.app",
//     messagingSenderId: "453171651477",
//     appId: "1:453171651477:web:b063a93aeddc69d28ccc9c",
//     measurementId: "G-2DWCB01VNS"
// });

// const messaging = firebase.messaging();

// messaging.onBackgroundMessage((payload) => {
//     console.log('Pesan latar belakang diterima. ', payload);
//     const notificationTitle = payload.notification.title;
//     const notificationOptions = {
//         body: payload.notification.body,
//         icon: '/firebase-logo.png' // Ganti dengan ikon yang sesuai
//     };

//     return self.registration.showNotification(notificationTitle, notificationOptions);
// });
importScripts("https://www.gstatic.com/firebasejs/7.23.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/7.23.0/firebase-messaging.js");
firebase.initializeApp({
        apiKey: "AIzaSyCo8JAAj1VfDVY_BaTnj71GIKuhJpX9NiU",
        authDomain: "sshchatfitur.firebaseapp.com",
        projectId: "sshchatfitur",
        storageBucket: "sshchatfitur.firebasestorage.app",
        messagingSenderId: "453171651477",
        appId: "1:453171651477:web:b063a93aeddc69d28ccc9c",
        measurementId: "G-2DWCB01VNS"
});
const messaging = firebase.messaging();
messaging.setBackgroundMessageHandler(function (payload) {
    const promiseChain = clients
        .matchAll({
            type: "window",
            includeUncontrolled: true
        })
        .then(windowClients => {
            for (let i = 0; i < windowClients.length; i++) {
                const windowClient = windowClients[i];
                windowClient.postMessage(payload);
            }
        })
        .then(() => {
            const title = payload.notification.title;
            const options = {
                body: payload.notification.score
            };
            return registration.showNotification(title, options);
        });
    return promiseChain;
});
self.addEventListener('notificationclick', function (event) {
    console.log('notification received: ', event)
});