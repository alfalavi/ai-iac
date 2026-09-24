import { useState, useEffect, useRef } from "react";

const API_BASE = "/api/todos";

const PALETTE = {
  light: {
    tealDark: "#0d9488",
    teal: "#14b8a6",
    tealLight: "#99f6e4",
    tealFaint: "#f0fdfa",
    bgDark: "#0f2027",
    bgMid: "#1a3a3a",
    card: "#ffffff",
    body: "#ffffff",
    itemBg: "#ffffff",
    inputBg: "#ffffff",
    footerBg: "#ffffff",
    border: "#e2e8f0",
    text: "#0f172a",
    textMuted: "#94a3b8",
    slate: "#64748b",
    danger: "#ef4444",
  },
  dark: {
    tealDark: "#0d9488",
    teal: "#14b8a6",
    tealLight: "#99f6e4",
    tealFaint: "#0d2520",
    bgDark: "#0f2027",
    bgMid: "#1a3a3a",
    card: "#1a2e2e",
    body: "#1a2e2e",
    itemBg: "#213535",
    inputBg: "#213535",
    footerBg: "#1a2e2e",
    border: "#2d4a4a",
    text: "#e2e8f0",
    textMuted: "#64748b",
    slate: "#94a3b8",
    danger: "#ef4444",
  },
};

const CONFETTI_COLORS = [
  "#14b8a6",
  "#0d9488",
  "#99f6e4",
  "#fbbf24",
  "#f472b6",
  "#818cf8",
  "#ffffff",
];

function makeStyles(C) {
  return {
    page: {
      minHeight: "100vh",
      background: `linear-gradient(160deg, ${C.bgDark} 0%, ${C.bgMid} 50%, #0d3d3a 100%)`,
      display: "flex",
      alignItems: "flex-start",
      justifyContent: "center",
      padding: "3rem 1rem",
    },
    card: {
      background: C.card,
      borderRadius: "20px",
      boxShadow: `0 25px 70px rgba(0,0,0,0.4), 0 0 0 1px rgba(20,184,166,0.15)`,
      width: "100%",
      maxWidth: "560px",
      overflow: "hidden",
      position: "relative",
    },
    header: {
      background: `linear-gradient(135deg, ${C.bgDark} 0%, ${C.tealDark} 100%)`,
      padding: "2rem",
      color: "#ffffff",
      position: "relative",
      overflow: "hidden",
    },
    headerAccent: {
      position: "absolute",
      top: "-30px",
      right: "-30px",
      width: "120px",
      height: "120px",
      borderRadius: "50%",
      background: `radial-gradient(circle, rgba(153,246,228,0.15) 0%, transparent 70%)`,
    },
    headerTitle: {
      fontSize: "1.75rem",
      fontWeight: 600,
      letterSpacing: "-0.02em",
      marginBottom: "0.25rem",
      position: "relative",
    },
    headerSub: {
      fontSize: "0.875rem",
      color: C.tealLight,
      opacity: 0.9,
      position: "relative",
    },
    body: {
      padding: "1.5rem",
      background: C.body,
    },
    form: {
      display: "flex",
      gap: "0.5rem",
      marginBottom: "1.5rem",
    },
    input: {
      flex: 1,
      padding: "0.75rem 1rem",
      border: `2px solid ${C.border}`,
      borderRadius: "10px",
      fontSize: "0.9375rem",
      outline: "none",
      transition: "border-color 0.15s, box-shadow 0.15s",
      fontFamily: "inherit",
      color: C.text,
      background: C.inputBg,
    },
    addBtn: {
      padding: "0.75rem 1.25rem",
      background: `linear-gradient(135deg, ${C.tealDark} 0%, ${C.teal} 100%)`,
      color: "#ffffff",
      border: "none",
      borderRadius: "10px",
      fontSize: "0.9375rem",
      fontWeight: 500,
      cursor: "pointer",
      whiteSpace: "nowrap",
      fontFamily: "inherit",
      transition: "opacity 0.15s",
    },
    stats: {
      display: "flex",
      gap: "0.5rem",
      marginBottom: "0.75rem",
      fontSize: "0.8125rem",
      color: C.slate,
      flexWrap: "wrap",
    },
    statBadge: {
      background: C.tealFaint,
      color: C.tealDark,
      borderRadius: "20px",
      padding: "0.25rem 0.625rem",
      fontWeight: 600,
      border: `1px solid ${C.tealLight}`,
    },
    progressTrack: {
      height: "6px",
      background: C.border,
      borderRadius: "99px",
      marginBottom: "1rem",
      overflow: "hidden",
    },
    progressFill: (pct) => ({
      height: "100%",
      width: `${pct}%`,
      background: `linear-gradient(90deg, ${C.tealDark}, ${C.teal})`,
      borderRadius: "99px",
      transition: "width 0.5s cubic-bezier(0.4, 0, 0.2, 1)",
    }),
    list: {
      listStyle: "none",
      display: "flex",
      flexDirection: "column",
      gap: "0.5rem",
    },
    item: (completed) => ({
      display: "flex",
      alignItems: "center",
      gap: "0.75rem",
      padding: "0.875rem 1rem",
      background: completed ? C.tealFaint : C.itemBg,
      border: `1.5px solid ${completed ? C.tealLight : C.border}`,
      borderRadius: "10px",
      transition: "border-color 0.15s, background 0.15s",
    }),
    checkbox: {
      width: "18px",
      height: "18px",
      cursor: "pointer",
      accentColor: C.tealDark,
      flexShrink: 0,
    },
    todoText: (completed) => ({
      flex: 1,
      fontSize: "0.9375rem",
      color: completed ? C.textMuted : C.text,
      textDecoration: completed ? "line-through" : "none",
      wordBreak: "break-word",
    }),
    deleteBtn: {
      background: "none",
      border: "none",
      cursor: "pointer",
      color: C.border,
      fontSize: "1.1rem",
      lineHeight: 1,
      padding: "0.25rem",
      borderRadius: "6px",
      transition: "color 0.15s",
      fontFamily: "inherit",
      flexShrink: 0,
    },
    empty: {
      textAlign: "center",
      padding: "2.5rem 1rem",
      color: C.textMuted,
      fontSize: "0.9375rem",
    },
    emptyIcon: {
      fontSize: "2.5rem",
      marginBottom: "0.5rem",
      color: C.teal,
    },
    footer: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: "0.5rem",
      padding: "1rem 1.5rem 1.5rem",
      borderTop: `1px solid ${C.border}`,
      background: C.footerBg,
    },
    copyright: {
      fontSize: "0.75rem",
      color: C.textMuted,
    },
  };
}

export default function App() {
  const [todos, setTodos] = useState([]);
  const [input, setInput] = useState("");
  const [inputFocused, setInputFocused] = useState(false);
  const [dark, setDark] = useState(false);
  const [confetti, setConfetti] = useState([]);
  const [greetingKey, setGreetingKey] = useState(0);
  const prevAllDone = useRef(false);

  const C = dark ? PALETTE.dark : PALETTE.light;
  const styles = makeStyles(C);

  // Inject CSS keyframes once
  useEffect(() => {
    const style = document.createElement("style");
    style.textContent = `
      @keyframes fadeSlideIn {
        from { opacity: 0; transform: translateX(-16px); }
        to   { opacity: 1; transform: translateX(0); }
      }
      @keyframes confettiBurst {
        0%   { opacity: 1; transform: translate(0, 0) rotate(0deg) scale(1); }
        100% { opacity: 0; transform: translate(var(--dx), var(--dy)) rotate(720deg) scale(0.3); }
      }
    `;
    document.head.appendChild(style);
    return () => document.head.removeChild(style);
  }, []);

  useEffect(() => {
    fetch(API_BASE)
      .then((r) => r.json())
      .then(setTodos)
      .catch(console.error);
  }, []);

  // Fire confetti when all todos become completed
  useEffect(() => {
    if (todos.length === 0) return;
    const allDone = todos.every((t) => t.completed);
    if (allDone && !prevAllDone.current) {
      const particles = Array.from({ length: 35 }, (_, i) => ({
        id: i,
        color: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
        dx: `${(Math.random() - 0.5) * 320}px`,
        dy: `${-(Math.random() * 220 + 60)}px`,
        left: `${20 + Math.random() * 60}%`,
        size: Math.random() * 9 + 5,
        delay: `${Math.random() * 0.4}s`,
        radius: Math.random() > 0.5 ? "50%" : "3px",
      }));
      setConfetti(particles);
      setTimeout(() => setConfetti([]), 1800);
    }
    prevAllDone.current = allDone;
  }, [todos]);

  function addTodo(e) {
    e.preventDefault();
    if (!input.trim()) return;
    fetch(API_BASE, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: input }),
    })
      .then((r) => r.json())
      .then((todo) => {
        setTodos((prev) => [...prev, todo]);
        setInput("");
      });
  }

  function toggleTodo(id, completed) {
    fetch(`${API_BASE}/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ completed: !completed }),
    })
      .then((r) => r.json())
      .then((updated) =>
        setTodos((prev) => prev.map((t) => (t.id === id ? updated : t))),
      );
  }

  function deleteTodo(id) {
    fetch(`${API_BASE}/${id}`, { method: "DELETE" }).then(() =>
      setTodos((prev) => prev.filter((t) => t.id !== id)),
    );
  }

  const completed = todos.filter((t) => t.completed).length;
  const pct =
    todos.length > 0 ? Math.round((completed / todos.length) * 100) : 0;
  const username =
    process.env.REACT_APP_USERNAME ||
    "AI Accelerated Engineering Bootcamp Participant";

  return (
    <div style={styles.page}>
      <div style={styles.card}>
        {/* Confetti burst */}
        {confetti.map((p) => (
          <div
            key={p.id}
            style={{
              position: "absolute",
              left: p.left,
              top: "45%",
              width: `${p.size}px`,
              height: `${p.size}px`,
              borderRadius: p.radius,
              background: p.color,
              "--dx": p.dx,
              "--dy": p.dy,
              animation: `confettiBurst 1.4s ${p.delay} ease-out forwards`,
              pointerEvents: "none",
              zIndex: 10,
            }}
          />
        ))}

        <div style={styles.header}>
          <div style={styles.headerAccent} />

          {/* Dark mode toggle */}
          <button
            onClick={() => setDark((d) => !d)}
            style={{
              position: "absolute",
              top: "1rem",
              right: "1rem",
              background: "rgba(255,255,255,0.15)",
              border: "1px solid rgba(255,255,255,0.25)",
              borderRadius: "8px",
              color: "#ffffff",
              cursor: "pointer",
              padding: "0.3rem 0.55rem",
              fontSize: "1rem",
              lineHeight: 1,
            }}
            aria-label="Toggle dark mode"
          >
            {dark ? "☀️" : "🌙"}
          </button>

          <div style={styles.headerTitle}>Todo Service</div>
          <div style={styles.headerSub}>
            Slalom AI Accelerated Engineering Bootcamp
          </div>
        </div>

        <div style={styles.body}>
          <form onSubmit={addTodo} style={styles.form}>
            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onFocus={() => setInputFocused(true)}
              onBlur={() => setInputFocused(false)}
              placeholder="Add a new task..."
              style={{
                ...styles.input,
                borderColor: inputFocused ? C.teal : C.border,
                boxShadow: inputFocused
                  ? `0 0 0 3px rgba(20,184,166,0.15)`
                  : "none",
              }}
              aria-label="New todo title"
            />
            <button
              type="submit"
              style={styles.addBtn}
              onMouseOver={(e) => (e.currentTarget.style.opacity = "0.85")}
              onMouseOut={(e) => (e.currentTarget.style.opacity = "1")}
            >
              Add task
            </button>
          </form>

          {todos.length > 0 && (
            <>
              <div style={styles.stats}>
                <span style={styles.statBadge}>{todos.length} total</span>
                <span style={styles.statBadge}>{completed} done</span>
                <span style={styles.statBadge}>
                  {todos.length - completed} remaining
                </span>
              </div>
              <div style={styles.progressTrack}>
                <div style={styles.progressFill(pct)} />
              </div>
            </>
          )}

          {todos.length === 0 ? (
            <div style={styles.empty}>
              <div style={styles.emptyIcon}>✓</div>
              <div>No tasks yet — add one above</div>
            </div>
          ) : (
            <ul style={styles.list}>
              {todos.map((todo) => (
                <li key={todo.id} style={styles.item(todo.completed)}>
                  <input
                    type="checkbox"
                    checked={todo.completed}
                    onChange={() => toggleTodo(todo.id, todo.completed)}
                    style={styles.checkbox}
                    aria-label={`Mark "${todo.title}" as ${todo.completed ? "incomplete" : "complete"}`}
                  />
                  <span style={styles.todoText(todo.completed)}>
                    {todo.title}
                  </span>
                  <button
                    onClick={() => deleteTodo(todo.id)}
                    style={styles.deleteBtn}
                    onMouseOver={(e) =>
                      (e.currentTarget.style.color = C.danger)
                    }
                    onMouseOut={(e) => (e.currentTarget.style.color = C.border)}
                    aria-label={`Delete "${todo.title}"`}
                  >
                    ✕
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div style={styles.footer}>
          <div
            style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}
          >
            <img
              src="/image.png"
              alt="Slalom"
              style={{ height: "48px", cursor: "pointer" }}
              onMouseEnter={() => setGreetingKey((k) => k + 1)}
            />
            <div
              key={greetingKey}
              style={{
                background: C.tealFaint,
                border: `1px solid ${C.tealLight}`,
                borderRadius: "12px",
                padding: "0.4rem 0.75rem",
                fontSize: "0.8125rem",
                color: C.tealDark,
                fontWeight: 500,
                animation: "fadeSlideIn 0.6s 0.3s ease both",
              }}
            >
              Hi, {username}! Your app is live and running 🚀
            </div>
          </div>
          <span style={styles.copyright}>
            © 2026 Slalom. All rights reserved.
          </span>
        </div>
      </div>
    </div>
  );
}
