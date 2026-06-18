import { useEffect, useState } from "react";

const FRONTEND_VERSION = __APP_VERSION__;

interface Item {
  id: number;
  name: string;
  note: string;
}

export function App() {
  const [backendVersion, setBackendVersion] = useState<string | null>(null);
  const [items, setItems] = useState<Item[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch("/api/v1/version")
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((d) => setBackendVersion(d.version))
      .catch((e) => setError(String(e)));

    fetch("/api/v1/items")
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then(setItems)
      .catch((e) => setError(String(e)));
  }, []);

  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem" }}>
      <h1>app1-java-react</h1>
      <p>Фронт: React + Vite. Бек: Spring Boot.</p>
      <ul>
        <li>Версия фронта 123: <b>{FRONTEND_VERSION}</b></li>
        <li>
          Версия бека (через REST):{" "}
          <b>{backendVersion ?? (error ? `ошибка: ${error}` : "загрузка…")}</b>
        </li>
      </ul>

      <h2>Записи из БД (таблица items)</h2>
      {error && <p style={{ color: "crimson" }}>Ошибка: {error}</p>}
      <table border={1} cellPadding={6} style={{ borderCollapse: "collapse" }}>
        <thead>
          <tr><th>id</th><th>name</th><th>note</th></tr>
        </thead>
        <tbody>
          {items.map((it) => (
            <tr key={it.id}>
              <td>{it.id}</td>
              <td>{it.name}</td>
              <td>{it.note}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </main>
  );
}
