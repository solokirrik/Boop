/*
 *  Base64 for Boop, backed by Foundation.
 *
 *  encode(text, urlSafe): text as UTF-8; urlSafe uses -_ and no padding.
 *  decode(text): accepts both alphabets, missing padding and whitespace.
 *  btoa/atob: binary strings (one character per byte), as in browsers.
 */

function encode(text, urlSafe) {
    return native.base64Encode(String(text), !!urlSafe)
}

function encodeURI(text) {
    return encode(text, true)
}

function decode(text) {
    return native.base64Decode(String(text))
}

function btoa(text) {
    const encoded = native.btoa(String(text))
    if (encoded == null) {
        throw new Error('btoa: the string has characters outside Latin-1')
    }
    return encoded
}

function atob(text) {
    return native.atob(String(text))
}

module.exports = {
    encode,
    encodeURI,
    decode,
    toBase64: encode,
    fromBase64: decode,
    btoa,
    atob
}
