-- Демо-схема app2-python-angular. Накатывается postgres автоматически при первой
-- инициализации кластера (/docker-entrypoint-initdb.d), без миграторов.
CREATE TABLE IF NOT EXISTS items (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    note TEXT
);

INSERT INTO items (name, note) VALUES
    ('Актив A-100', 'строка из init.sql'),
    ('Актив A-200', 'app2-python-angular'),
    ('Актив A-300', 'демо-запись');
