CREATE TABLE IF NOT EXISTS pilots (
 id text PRIMARY KEY, token_hash text UNIQUE NOT NULL, name text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS results (
 pilot_id text REFERENCES pilots(id) ON DELETE CASCADE,
 mode text NOT NULL CHECK (mode IN ('daily','weekly')),
 period date NOT NULL, route integer NOT NULL CHECK(route BETWEEN 0 AND 4),
 score integer NOT NULL CHECK(score BETWEEN 0 AND 200),
 moves integer NOT NULL CHECK(moves BETWEEN 1 AND 500),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (pilot_id, mode, period, route)
);
CREATE INDEX IF NOT EXISTS results_period ON results(mode, period);
-- Run as a scheduled maintenance operation: DELETE FROM results WHERE period < CURRENT_DATE - 90;
