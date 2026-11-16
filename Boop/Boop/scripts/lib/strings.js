/*
 *  String helpers for Boop: case conversion, deburr and character count.
 *
 *  Words are split the way lodash does it: on anything that isn't a letter
 *  or digit, on case changes (fooBar, XMLHttp) and between letters and
 *  digits. Apostrophes are dropped and accented Latin letters deburred
 *  first, so "Don't café" becomes "dontCafe".
 */

// Latin letters that don't decompose into a base letter plus accents.
const ligatures = {
    'Æ': 'Ae', 'æ': 'ae', 'Ø': 'O', 'ø': 'o', 'Ð': 'D', 'ð': 'd',
    'Þ': 'Th', 'þ': 'th', 'ß': 'ss', 'Đ': 'D', 'đ': 'd', 'Ħ': 'H', 'ħ': 'h',
    'ı': 'i', 'Ĳ': 'IJ', 'ĳ': 'ij', 'ĸ': 'k', 'Ŀ': 'L', 'ŀ': 'l', 'Ł': 'L',
    'ł': 'l', 'ŉ': "'n", 'Ŋ': 'N', 'ŋ': 'n', 'Œ': 'Oe', 'œ': 'oe', 'Ŧ': 'T',
    'ŧ': 't', 'ſ': 's'
}

const combiningMarks = /[̀-ͯ︠-︯⃐-⃿]/g

// Latin-1 Supplement and Latin Extended-A letters, as in lodash.
function deburr(text) {
    return String(text)
        .replace(/[À-ÖØ-öø-ſ]/g, c =>
            ligatures[c] || c.normalize('NFD').replace(combiningMarks, ''))
        .replace(combiningMarks, '')
}

const wordPattern = new RegExp([
    '\\p{Lu}+(?=\\p{Lu}\\p{Ll})',   // XML in XMLHttp
    '\\p{Lu}?\\p{Ll}+',             // Word, word
    '\\p{Lu}+',                     // WORD
    '\\p{Nd}*(?:1st|2nd|3rd|(?![123])\\p{Nd}th)(?!\\p{Ll})',  // 1st, 42nd
    '\\p{Nd}*(?:1ST|2ND|3RD|(?![123])\\p{Nd}TH)(?!\\p{Lu})',  // 1ST
    '\\p{Nd}+',                     // 42
    '[\\p{L}\\p{N}]+'               // anything else: CJK, Lt, Lm, other numbers
].join('|'), 'gu')

function words(text) {
    return deburr(text).replace(/['’]/g, '').match(wordPattern) || []
}

const upperFirst = word => word.charAt(0).toUpperCase() + word.slice(1)

function camelCase(text) {
    return words(text)
        .map((word, i) => i === 0 ? word.toLowerCase() : upperFirst(word.toLowerCase()))
        .join('')
}

const joinLower = separator => text =>
    words(text).map(word => word.toLowerCase()).join(separator)

const kebabCase = joinLower('-')
const snakeCase = joinLower('_')
const lowerCase = joinLower(' ')

function startCase(text) {
    return words(text).map(upperFirst).join(' ')
}

// Characters as people count them: "é", "🇺🇦" and "👩‍👩‍👧" are one each.
function size(text) {
    return native.characterCount(String(text))
}

function escapeRegExp(text) {
    return String(text).replace(/[\\^$.*+?()[\]{}|]/g, '\\$&')
}

module.exports = {
    words,
    deburr,
    camelCase,
    kebabCase,
    snakeCase,
    lowerCase,
    startCase,
    size,
    escapeRegExp
}
