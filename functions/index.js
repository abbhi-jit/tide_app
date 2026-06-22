const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.checkOverdueTask = onDocumentWritten("users/{userId}/tasks/{taskId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const after = snapshot.after.data();
  if (!after) return; // Document deleted

  const userId = event.params.userId;
  
  if (after.isDone) return; // Task is completed, no notification

  const dueDate = new Date(after.dueDate).getTime();
  const now = Date.now();

  // If due date is in the past, send notification
  if (dueDate < now) {
    console.log(`Task ${after.title} for user ${userId} is overdue!`);
    
    // Fetch the FCM device token for the user from Firestore
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) {
      const message = {
        notification: {
          title: "Task Overdue!",
          body: `Your task "${after.title}" was due on ${new Date(after.dueDate).toDateString()}.`
        },
        token: fcmToken
      };

      try {
        await admin.messaging().send(message);
        console.log("Notification sent successfully");
      } catch (error) {
        console.error("Error sending notification:", error);
      }
    } else {
      console.log("No FCM token found for user", userId);
    }
  }
});
