const fs = require('fs');
const https = require('https');

// Path to the firebase-tools config
const configPath = '/Users/sanjarbek/.config/configstore/firebase-tools.json';

function getAccessToken() {
  if (!fs.existsSync(configPath)) {
    throw new Error(`Firebase configuration not found at ${configPath}`);
  }
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  if (!config.tokens || !config.tokens.access_token) {
    throw new Error('Access token not found in Firebase configuration. Please login first.');
  }
  return config.tokens.access_token;
}

function makeRequest(url, token) {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    };
    https.get(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Failed to parse response: ${data}`));
        }
      });
    }).on('error', reject);
  });
}

async function run() {
  try {
    const token = getAccessToken();
    const projectId = 'phonecontroller-5a1f4';
    
    // Test write
    const testWriteUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/logs`;
    console.log("Attempting a test write to Firestore logs collection...");
    const testBody = JSON.stringify({
      fields: {
        message: { stringValue: "Test write from CLI script" },
        timestamp: { stringValue: new Date().toISOString() }
      }
    });
    
    // Perform POST request
    const postOptions = {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    };
    
    const writeResult = await new Promise((resolve, reject) => {
      const req = https.request(testWriteUrl, postOptions, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => resolve(JSON.parse(data)));
      });
      req.on('error', reject);
      req.write(testBody);
      req.end();
    });

    console.log("Write response:", JSON.stringify(writeResult, null, 2));

    // 1. Fetch Logs
    const logsUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/logs?pageSize=15`;
    console.log("\nFetching logs from Firestore REST API...");
    const logsData = await makeRequest(logsUrl, token);
    
    if (logsData.documents && logsData.documents.length > 0) {
      // Sort logs by timestamp ascending for readability
      const sortedDocs = logsData.documents.map(doc => {
        const fields = doc.fields || {};
        const message = fields.message?.stringValue || 'no-message';
        const timestamp = fields.timestamp?.timestampValue || 'no-timestamp';
        return { message, timestamp };
      }).sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

      sortedDocs.forEach(log => {
        console.log(`[${log.timestamp}] ${log.message}`);
      });
    } else {
      console.log("No logs found in Firestore.");
    }

    // 2. Fetch Screenshot Document
    const screenshotUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/device_data/screenshot`;
    console.log("\nFetching screenshot document metadata from Firestore...");
    const screenshotData = await makeRequest(screenshotUrl, token);
    
    if (screenshotData.fields) {
      const fields = screenshotData.fields;
      const timestamp = fields.timestamp?.timestampValue || 'no-timestamp';
      const base64 = fields.base64?.stringValue || '';
      console.log("Screenshot document exists in Firestore!");
      console.log(`Timestamp: ${timestamp}`);
      console.log(`Base64 length: ${base64.length} characters`);
      
      if (base64.length > 0) {
        const buffer = Buffer.from(base64, 'base64');
        fs.writeFileSync('screenshot_firestore.png', buffer);
        console.log("Saved screenshot to screenshot_firestore.png");
      }
    } else {
      console.log("Screenshot document not found or empty.");
    }

  } catch (error) {
    console.error("Error:", error.message);
  }
}

run();
