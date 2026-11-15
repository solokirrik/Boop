/**
  {
    "api":1,
    "name":"From Unicode Escaped String",
    "description":"Decodes unicode escapes (\\u00e9, \\u{1F600}) into readable text",
    "author":"luisfontes19",
    "icon":"broom",
    "tags":"string,normalize,convert,readable,unicode,unescape,decode"
  }
**/

function main(state) {
  state.text = fromUnicode(state.text);
}

// Decodes \uXXXX and \u{X...} escapes, leaving any other text untouched.
// Surrogate pairs (😀) recombine naturally into one character.
function fromUnicode(str) {
  return str.replace(/\\u\{([0-9a-f]{1,6})\}|\\u([0-9a-f]{4})/gi, (match, codePoint, codeUnit) => {
    if (codePoint) {
      const value = parseInt(codePoint, 16);
      return value <= 0x10ffff ? String.fromCodePoint(value) : match;
    }
    return String.fromCharCode(parseInt(codeUnit, 16));
  });
}
