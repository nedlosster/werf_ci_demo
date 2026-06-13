import { useEffect, useState } from "react";

const FRONTEND_VERSION = __APP_VERSION__;

export function App() {
  const [backendVersion, setBackendVersion] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch("/api/v1/version")
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((d) => setBackendVersion(d.version))
      .catch((e) => setError(String(e)));
  }, []);

  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem" }}>
      <h1>app1-java-react</h1>
      <p>Фронт: React + Vite. Бек: Spring Boot.</p>
      <ul>
        <li>Версия фронта: <b>{FRONTEND_VERSION}</b></li>
        <li>
          Версия бека (через REST):{" "}
          <b>{backendVersion ?? (error ? `ошибка: ${error}` : "загрузка…")}</b>
        </li>
      </ul>
    </main>
  );
}
