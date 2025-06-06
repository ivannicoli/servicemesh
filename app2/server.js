const express = require('express');
const axios = require('axios');
const app = express();
const port = process.env.PORT || 8080;

// The service name used for service discovery
// In Kubernetes, this will be the service name of app1
const APP1_SERVICE = process.env.APP1_SERVICE || 'app1';
const APP1_PORT = process.env.APP1_PORT || '8080';
const APP1_URL = `http://${APP1_SERVICE}:${APP1_PORT}`;

app.get('/health', (req, res) => {
  res.status(200).send('Healthy');
});

app.get('/', async (req, res) => {
  const serviceName = process.env.SERVICE_NAME || 'app2';
  const version = process.env.SERVICE_VERSION || 'v1';
  const hostname = require('os').hostname();
  
  const app2Response = {
    service: serviceName,
    version: version,
    hostname: hostname,
    message: 'Hello from App2!',
    timestamp: new Date().toISOString(),
    app1Response: null
  };
  
  console.log(`Request received at ${app2Response.timestamp}`);
  
  try {
    console.log(`Calling App1 at ${APP1_URL}`);
    const app1Result = await axios.get(APP1_URL);
    app2Response.app1Response = app1Result.data;
    console.log('Successfully received response from App1');
  } catch (error) {
    console.error('Error calling App1:', error.message);
    app2Response.app1Response = { error: `Failed to call App1: ${error.message}` };
  }
  
  res.json(app2Response);
});

app.listen(port, () => {
  console.log(`App2 listening on port ${port}`);
  console.log(`Configured to call App1 at: ${APP1_URL}`);
});
