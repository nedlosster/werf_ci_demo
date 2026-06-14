import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import pkg from "./package.json";

export default defineConfig({
  plugins: [react()],
  // версия фронта из package.json -> доступна в коде как __APP_VERSION__
  define: {
    __APP_VERSION__: JSON.stringify(pkg.version),
  },
  server: {
    port: 5173,
    host: true,
    // dev-сервер в кластере доступен через ingress по nip.io-хосту;
    // без этого Vite 5 отвечает 403 на незнакомый Host. Демо-послабление.
    allowedHosts: [".nip.io"],
  },
});
