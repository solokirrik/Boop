/**
{
  "api":1,
  "name":"Box Table to Markdown",
  "description":"Converts a box-drawing (┌─┬─┐ │ │) or ASCII (+---+) table into a markdown table.",
  "author":"Kirill",
  "icon":"table",
  "tags":"table,markdown,md,box,ascii,pseudographic,unicode,convert"
}
**/

// Characters that make up border and separator lines.
const BORDER = /^[\s─━═┌┍┎┏┐┑┒┓└┕┖┗┘┙┚┛├┝┞┟┠┡┢┣┤┥┦┧┨┩┪┫┬┭┮┯┰┱┲┳┴┵┶┷┸┹┺┻┼┽┾┿╀╁╂╃╄╅╆╇╈╉╊╋╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫╬╭╮╯╰+\-=:|│┃║]*$/;
// Characters that separate cells inside a content line.
const CELL_SEP = /[│┃║|]/;

function main(state) {
  const lines = state.text.split(/\r?\n/).filter(l => l.trim() !== "");
  if (lines.length === 0) return;

  // Group content lines into blocks; a separator line ends a block.
  const blocks = [];
  let current = [];
  for (const line of lines) {
    if (BORDER.test(line) && !/[A-Za-z0-9]/.test(line)) {
      if (current.length) blocks.push(current);
      current = [];
    } else {
      current.push(splitCells(line));
    }
  }
  if (current.length) blocks.push(current);
  if (blocks.length === 0) {
    state.postError("No table rows found");
    return;
  }

  // With separators between body rows, each block is one row whose cells
  // wrap over several lines. Otherwise (only a header separator), every
  // content line is its own row.
  let rows;
  if (blocks.length > 2) {
    rows = blocks.map(mergeBlock);
  } else {
    rows = [mergeBlock(blocks[0])];
    if (blocks[1]) rows.push(...blocks[1]);
  }

  const cols = Math.max(...rows.map(r => r.length));
  rows = rows.map(r => {
    const out = r.map(c => c.replace(/\|/g, "\\|"));
    while (out.length < cols) out.push("");
    return out;
  });

  const widths = [];
  for (let i = 0; i < cols; i++) {
    widths.push(Math.max(3, ...rows.map(r => [...r[i]].length)));
  }
  const pad = (s, w) => s + " ".repeat(w - [...s].length);
  const fmt = r => "| " + r.map((c, i) => pad(c, widths[i])).join(" | ") + " |";

  const [header, ...body] = rows;
  state.text = [
    fmt(header),
    "| " + widths.map(w => "-".repeat(w)).join(" | ") + " |",
    ...body.map(fmt),
  ].join("\n");
}

function splitCells(line) {
  // Box tables split only on box bars, so a literal "|" in a cell survives.
  let parts = line.trim().split(/[│┃║]/.test(line) ? /[│┃║]/ : CELL_SEP);
  // Drop the empty pieces outside the outer borders.
  if (parts.length > 1 && parts[0].trim() === "") parts = parts.slice(1);
  if (parts.length > 1 && parts[parts.length - 1].trim() === "") parts = parts.slice(0, -1);
  return parts.map(p => p.trim());
}

// Joins the wrapped lines of one logical row, cell by cell.
function mergeBlock(block) {
  const cols = Math.max(...block.map(r => r.length));
  const row = [];
  for (let i = 0; i < cols; i++) {
    row.push(block.map(r => r[i] || "").filter(Boolean).join(" "));
  }
  return row;
}
