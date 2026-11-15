/**
  {
    "api":1,
    "name":"To Unicode Escaped String",
    "description":"Converts a UTF8 string to unicode escape chars(js format)",
    "author":"luisfontes19",
    "icon":"broom",
    "tags":"string,unicode,convert,escape,encode"
  }
**/

function main(state) {
  state.text = toUnicode(state.text);
}

// Escapes every UTF-16 code unit as \uXXXX, so characters outside the
// BMP (emoji) become surrogate pairs, exactly like JS string literals.
function toUnicode(str) {
  let out = "";
  for (let i = 0; i < str.length; i++) {
    out += "\\u" + str.charCodeAt(i).toString(16).padStart(4, "0");
  }
  return out;
}
