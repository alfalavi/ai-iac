const express = require('express');
const cors = require('cors');
const client = require('prom-client');
const todoService = require('./services/todoService');

const app = express();

// ---------------------------------------------------------------
// Prometheus metrics setup
// ---------------------------------------------------------------
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

const httpRequestDurationSeconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [register],
});

// ---------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------
app.use(cors());
app.use(express.json());

// Metrics middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.path : req.path.replace(/\/\d+/g, '/:id');
    httpRequestsTotal.inc({ method: req.method, route, status: res.statusCode });
    httpRequestDurationSeconds.observe({ method: req.method, route, status: res.statusCode }, duration);
  });
  next();
});

// ---------------------------------------------------------------
// Routes
// ---------------------------------------------------------------
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/api/todos', (req, res) => {
  res.json(todoService.getAll());
});

app.post('/api/todos', (req, res) => {
  const { title } = req.body;
  if (!title || typeof title !== 'string' || !title.trim()) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', message: 'title is required' });
  }
  const todo = todoService.create(title.trim());
  res.status(201).json(todo);
});

app.put('/api/todos/:id', (req, res) => {
  const todo = todoService.update(req.params.id, req.body);
  if (!todo) {
    return res.status(404).json({ error: 'NOT_FOUND', message: `Todo ${req.params.id} not found` });
  }
  res.json(todo);
});

app.delete('/api/todos/:id', (req, res) => {
  const deleted = todoService.remove(req.params.id);
  if (!deleted) {
    return res.status(404).json({ error: 'NOT_FOUND', message: `Todo ${req.params.id} not found` });
  }
  res.status(204).send();
});

module.exports = app;
