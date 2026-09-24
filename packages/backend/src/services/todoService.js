const { v4: uuidv4 } = require('uuid');

let todos = [];

function getAll() {
  return todos;
}

function getById(id) {
  return todos.find((t) => t.id === id) || null;
}

function create(title) {
  const todo = {
    id: uuidv4(),
    title,
    completed: false,
    createdAt: new Date().toISOString(),
  };
  todos.push(todo);
  return todo;
}

function update(id, changes) {
  const idx = todos.findIndex((t) => t.id === id);
  if (idx === -1) return null;
  todos[idx] = { ...todos[idx], ...changes, id };
  return todos[idx];
}

function remove(id) {
  const idx = todos.findIndex((t) => t.id === id);
  if (idx === -1) return false;
  todos.splice(idx, 1);
  return true;
}

// Reset for testing
function _reset() {
  todos = [];
}

module.exports = { getAll, getById, create, update, remove, _reset };
