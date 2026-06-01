const admin = require('firebase-admin');

// Initialize Firebase Admin using Application Default Credentials
admin.initializeApp({
  projectId: 'phonecontroller-5a1f4'
});

const db = admin.firestore();

async function readLogs() {
  console.log("Fetching latest logs from Firestore...");
  const snapshot = await db.collection('logs').orderBy('timestamp', 'desc').limit(15).get();
  if (snapshot.empty) {
    console.log("No logs found.");
    return;
  }
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log(`[${data.timestamp?.toDate()?.toISOString() || 'no-time'}] ${data.message}`);
  });
}

async function checkScreenshot() {
  console.log("\nChecking screenshot document...");
  const doc = await db.collection('device_data').doc('screenshot').get();
  if (!doc.exists) {
    console.log("No screenshot document found.");
  } else {
    const data = doc.data();
    console.log("Screenshot document exists!");
    console.log(`Timestamp: ${data.timestamp?.toDate()?.toISOString()}`);
    if (data.base64) {
      console.log(`Base64 length: ${data.base64.length} characters`);
      // Save it locally to verify it's a valid PNG
      const fs = require('fs');
      const buffer = Buffer.from(data.base64, 'base64');
      fs.writeFileSync('screenshot_firestore.png', buffer);
      console.log("Saved Firestore screenshot to screenshot_firestore.png");
    } else {
      console.log("Base64 string is empty.");
    }
  }
}

async function run() {
  try {
    await readLogs();
    await checkScreenshot();
  } catch (error) {
    console.error("Error reading Firestore:", error);
  }
}

run();
