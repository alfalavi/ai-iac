const request = require('supertest');
const app = require('../src/app');
const todoService = require('../src/services/todoService');

beforeEach(() => {
  todoService._reset();
});

describe('GET /health', () => {
  it('returns 200 with status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('GET /metrics', () => {
  it('returns prometheus metrics', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toMatch(/http_requests_total/);
  });
});

describe('GET /api/todos', () => {
  it('returns empty array when no todos', async () => {
    const res = await request(app).get('/api/todos');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('returns all todos', async () => {
    todoService.create('Buy milk');
    todoService.create('Walk dog');
    const res = await request(app).get('/api/todos');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
  });
});

describe('POST /api/todos', () => {
  it('creates a new todo', async () => {
    const res = await request(app).post('/api/todos').send({ title: 'Write tests' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ title: 'Write tests', completed: false });
    expect(res.body.id).toBeDefined();
  });

  it('returns 400 when title is missing', async () => {
    const res = await request(app).post('/api/todos').send({});
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('VALIDATION_ERROR');
  });

  it('returns 400 when title is empty string', async () => {
    const res = await request(app).post('/api/todos').send({ title: '  ' });
    expect(res.status).toBe(400);
  });

  it('returns 400 when title is not a string', async () => {
    const res = await request(app).post('/api/todos').send({ title: 123 });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('VALIDATION_ERROR');
  });
});

describe('PUT /api/todos/:id', () => {
  it('updates an existing todo', async () => {
    const todo = todoService.create('Draft PR');
    const res = await request(app)
      .put(`/api/todos/${todo.id}`)
      .send({ completed: true });
    expect(res.status).toBe(200);
    expect(res.body.completed).toBe(true);
  });

  it('returns 404 for unknown id', async () => {
    const res = await request(app).put('/api/todos/nonexistent').send({ completed: true });
    expect(res.status).toBe(404);
  });
});

describe('todoService.getById', () => {
  it('returns null for non-existent id', () => {
    expect(todoService.getById('missing')).toBeNull();
  });
});

describe('DELETE /api/todos/:id', () => {
  it('deletes an existing todo', async () => {
    const todo = todoService.create('Delete me');
    const res = await request(app).delete(`/api/todos/${todo.id}`);
    expect(res.status).toBe(204);
  });

  it('returns 404 for unknown id', async () => {
    const res = await request(app).delete('/api/todos/nonexistent');
    expect(res.status).toBe(404);
  });
});
