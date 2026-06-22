const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenerativeAI } = require("@google/generative-ai");
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

const geminiApiKey = defineSecret('GEMINI_API_KEY');

exports.askAssistant = onCall({ secrets: [geminiApiKey] }, async (request) => {
  try {
    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({
      model: "gemini-1.5-flash",
      systemInstruction: "You are a helpful, concise AI assistant built directly into the Tide task management app. Your job is to assist the user with managing their tasks and schedule. You will be provided with the user's current tasks in the system context. Base all your summaries and answers strictly on the app data provided."
    });

    const message = request.data.message;
    const contextText = request.data.contextText;
    const prompt = `App Context:\n${contextText}\n\nUser Message: ${message}`;
    
    const result = await model.generateContent(prompt);
    return { response: result.response.text() };
  } catch (error) {
    console.error("Gemini Error:", error);
    throw new Error("Failed to generate AI response.");
  }
});
