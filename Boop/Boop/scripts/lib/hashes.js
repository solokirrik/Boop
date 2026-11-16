/*
 *  Hashes for Boop, backed by CryptoKit.
 *
 *  Keeps the jshashes shape scripts already use:
 *    const Hashes = require('@boop/hashes')
 *    new Hashes.SHA256().hex(text)
 *
 *  Text is hashed as UTF-8. Hex output is lowercase.
 */

function hasher(algorithm) {
    return function () {
        this.hex = text => native.digest(algorithm, String(text), 'hex')
        this.b64 = text => native.digest(algorithm, String(text), 'base64')
        this.hex_hmac = (key, text) => native.hmac(algorithm, String(key), String(text), 'hex')
        this.b64_hmac = (key, text) => native.hmac(algorithm, String(key), String(text), 'base64')
    }
}

module.exports = {
    MD5: hasher('md5'),
    SHA1: hasher('sha1'),
    SHA256: hasher('sha256'),
    SHA512: hasher('sha512')
}
