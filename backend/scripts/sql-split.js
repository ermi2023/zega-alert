// Splits a SQL script into individual statements, correctly ignoring
// semicolons that appear inside dollar-quoted blocks (DO $$ ... $$),
// single-quoted strings, and comments.
export function splitStatements(sql) {
  const stmts = [];
  let buf = '';
  let i = 0;
  const n = sql.length;

  while (i < n) {
    const c = sql[i];

    // Line comment
    if (c === '-' && sql[i + 1] === '-') {
      while (i < n && sql[i] !== '\n') i++;
      continue;
    }

    // Block comment
    if (c === '/' && sql[i + 1] === '*') {
      i += 2;
      while (i < n && !(sql[i] === '*' && sql[i + 1] === '/')) i++;
      i += 2;
      continue;
    }

    // Single-quoted string (with '' escaping)
    if (c === "'") {
      buf += c;
      i++;
      while (i < n) {
        buf += sql[i];
        if (sql[i] === "'") {
          if (sql[i + 1] === "'") {
            buf += sql[i + 1];
            i += 2;
            continue;
          }
          i++;
          break;
        }
        i++;
      }
      continue;
    }

    // Dollar-quoted string ($$ ... $$ or $tag$ ... $tag$)
    if (c === '$') {
      const m = /^\$[A-Za-z0-9_]*\$/.exec(sql.slice(i));
      if (m) {
        const tag = m[0];
        buf += tag;
        i += tag.length;
        const end = sql.indexOf(tag, i);
        if (end === -1) {
          buf += sql.slice(i);
          i = n;
        } else {
          buf += sql.slice(i, end + tag.length);
          i = end + tag.length;
        }
        continue;
      }
    }

    // Statement terminator
    if (c === ';') {
      const s = buf.trim();
      if (s) stmts.push(s);
      buf = '';
      i++;
      continue;
    }

    buf += c;
    i++;
  }

  const tail = buf.trim();
  if (tail) stmts.push(tail);
  return stmts;
}
