import { Component, signal } from "@angular/core";
import { HttpClient } from "@angular/common/http";
import { version as frontendVersion } from "../../package.json";

interface Item {
  id: number;
  name: string;
  note: string;
}

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

      <h2>Записи из БД (таблица items)</h2>
      <table border="1" cellpadding="6" style="border-collapse: collapse;">
        <thead>
          <tr><th>id</th><th>name</th><th>note</th></tr>
        </thead>
        <tbody>
          @for (it of items(); track it.id) {
            <tr>
              <td>{{ it.id }}</td>
              <td>{{ it.name }}</td>
              <td>{{ it.note }}</td>
            </tr>
          }
        </tbody>
      </table>
    </main>
  `,
})
export class AppComponent {
  frontendVersion = frontendVersion;
  backendVersion = signal("загрузка…");
  items = signal<Item[]>([]);

  constructor(http: HttpClient) {
    http.get<{ version: string }>("/api/v1/version").subscribe({
      next: (d) => this.backendVersion.set(d.version),
      error: (e) => this.backendVersion.set("ошибка: " + e.status),
    });
    http.get<Item[]>("/api/v1/items").subscribe({
      next: (d) => this.items.set(d),
      error: () => this.items.set([]),
    });
  }
}
