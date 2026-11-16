/*
 *  HTML escape/unescape for Boop.
 *
 *  encode: escapes & < > " ' only; everything else is left as is.
 *  decode: unescapes those, numeric references (&#233; &#xE9;) and a
 *  short list of common named entities. Unknown names are left as is.
 */

const escapes = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
}

const named = {
    amp: '&', lt: '<', gt: '>', quot: '"', apos: "'",
    nbsp: ' ', copy: '©', reg: '®', trade: '™',
    hellip: '…', mdash: '—', ndash: '–',
    laquo: '«', raquo: '»',
    lsquo: '‘', rsquo: '’', ldquo: '“', rdquo: '”',
    bull: '•', middot: '·', deg: '°',
    euro: '€', pound: '£', yen: '¥', cent: '¢',
    times: '×', divide: '÷'
}

function encode(text) {
    return String(text).replace(/[&<>"']/g, c => escapes[c])
}

function decode(text) {
    return String(text).replace(
        /&(?:#[xX]([0-9a-fA-F]+)|#([0-9]+)|([a-zA-Z][a-zA-Z0-9]*));/g,
        (match, hex, dec, name) => {
            if (name) {
                return Object.prototype.hasOwnProperty.call(named, name) ? named[name] : match
            }
            const code = hex ? parseInt(hex, 16) : parseInt(dec, 10)
            if (code === 0 || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)) {
                return '�'
            }
            return String.fromCodePoint(code)
        }
    )
}

module.exports = { encode, decode, escape: encode, unescape: decode }
