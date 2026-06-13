-- Демо-схема app1-java-react. Накатывается postgres автоматически при первой
-- инициализации кластера (/docker-entrypoint-initdb.d), без миграторов.
CREATE TABLE IF NOT EXISTS items (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    note TEXT
);

INSERT INTO items (name, note) VALUES
    ('Сервер CI-001', 'строка из init.sql'),
    ('Сервис billing', 'app1-java-react'),
    ('База данных pg-01', 'демо-запись');
