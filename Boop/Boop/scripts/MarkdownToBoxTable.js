/**
{
  "api":1,
  "name":"Markdown to Box Table",
  "description":"Converts a markdown table into a box-drawing (┌─┬─┐ │ │) table.",
  "author":"Kirill Tishenkov",
  "icon":"table",
  "tags":"table,markdown,md,box,ascii,pseudographic,unicode,convert"
}
**/

function main(state) {
  const lines = state.text.split(/\r?\n/).filter(l => l.trim() !== "");
  const rows = lines.map(splitRow);
  const sepIndex = rows.findIndex(isAlignmentRow);
  if (rows.length === 0 || sepIndex === -1) {
    state.postError("No markdown table found");
    return;
  }

  const align = rows[sepIndex].map(c => {
    const l = c.startsWith(":"), r = c.endsWith(":");
    return l && r ? "center" : r ? "right" : "left";
  });
  const header = rows.slice(0, sepIndex);
  const body = rows.slice(sepIndex + 1);

  const cols = Math.max(...rows.map(r => r.length));
  const norm = r => { const o = r.slice(); while (o.length < cols) o.push(""); return o; };
  const all = [...header, ...body].map(norm);
  const widths = [];
  for (let i = 0; i < cols; i++) widths.push(Math.max(1, ...all.map(r => len(r[i]))));

  const line = (l, m, r) => l + widths.map(w => "─".repeat(w + 2)).join(m) + r;
  const fmt = (row, how) => "│" + norm(row).map((c, i) => " " + place(c, widths[i], how(i)) + " ").join("│") + "│";

  const out = [line("┌", "┬", "┐")];
  header.forEach(r => out.push(fmt(r, () => "center")));
  body.forEach(r => {
    out.push(line("├", "┼", "┤"));
    out.push(fmt(r, i => align[i] || "left"));
  });
  out.push(line("└", "┴", "┘"));
  state.text = out.join("\n");
}

// Splits "| a | b \| c |" into cells, keeping escaped pipes as literal "|".
function splitRow(line) {
  let s = line.trim();
  if (s.startsWith("|")) s = s.slice(1);
  if (s.endsWith("|") && !s.endsWith("\\|")) s = s.slice(0, -1);
  return s.split(/(?<!\\)\|/).map(c => c.trim().replace(/\\\|/g, "|"));
}

function isAlignmentRow(row) {
  return row.length > 0 && row.every(c => /^:?-+:?$/.test(c));
}

function len(s) {
  return [...s].length;
}

function place(s, w, how) {
  const gap = w - len(s);
  if (how === "right") return " ".repeat(gap) + s;
  if (how === "center") {
    const left = Math.floor(gap / 2);
    return " ".repeat(left) + s + " ".repeat(gap - left);
  }
  return s + " ".repeat(gap);
}
