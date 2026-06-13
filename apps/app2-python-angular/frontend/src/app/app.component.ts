import { Component, signal } from "@angular/core";
import { HttpClient } from "@angular/common/http";
import { version as frontendVersion } from "../../package.json";

@Component({
  selector: "app-root",
  standalone: true,
  template: `
    <main style="font-family: sans-serif; padding: 2rem;">
      <h1>app2-python-angular</h1>
      <p>Фронт: Angular. Бек: FastAPI.</p>
      <ul>
        <li>Версия фронта: <b>{{ frontendVersion }}</b></li>
        <li>Версия бека (через REST): <b>{{ backendVersion() }}</b></li>
      </ul>
    </main>
  `,
})
export class AppComponent {
  frontendVersion = frontendVersion;
  backendVersion = signal("загрузка…");

  constructor(http: HttpClient) {
    http.get<{ version: string }>("/api/v1/version").subscribe({
      next: (d) => this.backendVersion.set(d.version),
      error: (e) => this.backendVersion.set("ошибка: " + e.status),
    });
  }
}
