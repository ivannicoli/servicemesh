const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.get('/health', (req, res) => {
  res.status(200).send('Healthy');
});

app.get('/', (req, res) => {
  const serviceName = process.env.SERVICE_NAME || 'app1';
  const version = process.env.SERVICE_VERSION || 'v1';
  const hostname = require('os').hostname();
  
  const response = {
    service: serviceName,
    version: version,
    hostname: hostname,
    message: 'Hello from App1!',
    timestamp: new Date().toISOString()
  };
  
  console.log(`Request received at ${response.timestamp}`);
  res.json(response);
});

app.listen(port, () => {
  console.log(`App1 listening on port ${port}`);
});
