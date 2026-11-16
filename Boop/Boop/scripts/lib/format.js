/*
 *  Formatters and minifiers for Boop: XML, CSS and SQL.
 *
 *  xml, xmlmin:  parsed by Foundation's XMLDocument; malformed XML throws.
 *  css, cssmin:  tokenized, so strings, comments and url(...) stay intact.
 *  sql, sqlmin:  keyword based, but strings, quoted identifiers and comments
 *                are never changed.
 */

const indentUnit = '    '
const indent = depth => indentUnit.repeat(Math.max(depth, 0))

// ---------------------------------------------------------------- XML

function xmlResult(result) {
    if (result.error != null) {
        throw new Error(result.error)
    }
    return result.text
}

function xml(text) {
    return xmlResult(native.formatXML(String(text), false))
}

function xmlmin(text) {
    return xmlResult(native.formatXML(String(text), true))
}

// ---------------------------------------------------------------- CSS

// Splits CSS into strings, comments, whitespace and single characters.
// Characters inside parentheses are kept with the parentheses, so
// url(data:image/png;base64,...) is one token.
function cssTokens(text) {
    const tokens = []
    let i = 0
    while (i < text.length) {
        const c = text[i]
        if (c === '/' && text[i + 1] === '*') {
            const end = text.indexOf('*/', i + 2)
            const stop = end === -1 ? text.length : end + 2
            tokens.push({ type: 'comment', value: text.slice(i, stop) })
            i = stop
        } else if (c === '"' || c === "'") {
            let j = i + 1
            while (j < text.length && text[j] !== c) {
                j += text[j] === '\\' ? 2 : 1
            }
            tokens.push({ type: 'text', value: text.slice(i, j + 1) })
            i = j + 1
        } else if (/\s/.test(c)) {
            let j = i
            while (j < text.length && /\s/.test(text[j])) j++
            tokens.push({ type: 'space', value: ' ' })
            i = j
        } else if (c === '(') {
            let depth = 0
            let j = i
            let quote = null
            for (; j < text.length; j++) {
                const d = text[j]
                if (quote) {
                    if (d === '\\') j++
                    else if (d === quote) quote = null
                } else if (d === '"' || d === "'") quote = d
                else if (d === '(') depth++
                else if (d === ')' && --depth === 0) break
            }
            tokens.push({ type: 'text', value: text.slice(i, j + 1).replace(/\s+/g, ' ') })
            i = j + 1
        } else if ('{};'.includes(c)) {
            tokens.push({ type: c, value: c })
            i++
        } else {
            tokens.push({ type: 'text', value: c })
            i++
        }
    }
    return tokens
}

// Groups tokens into statements: a prelude ending in "{", a declaration
// ending in ";" or "}", a "}" or a standalone comment.
function cssStatements(text) {
    const statements = []
    let buffer = ''
    const flush = kind => {
        const value = buffer.trim()
        buffer = ''
        if (value || kind === 'open') statements.push({ kind, value })
    }
    for (const token of cssTokens(text)) {
        switch (token.type) {
        case '{': flush('open'); break
        case ';': flush('declaration'); break
        case '}': flush('declaration'); statements.push({ kind: 'close' }); break
        case 'comment':
            if (buffer.trim()) buffer += token.value
            else statements.push({ kind: 'comment', value: token.value })
            break
        default: buffer += token.value
        }
    }
    flush('declaration')
    return statements
}

// "color : red" -> "color: red"; leaves @rules and anything else alone.
function cssDeclaration(value, separator) {
    const match = /^(--[\w-]*|-?[a-zA-Z][\w-]*)\s*:\s*([\s\S]*)$/.exec(value)
    return match ? match[1] + ':' + separator + match[2] : value
}

function css(text) {
    const lines = []
    let depth = 0
    for (const statement of cssStatements(String(text))) {
        switch (statement.kind) {
        case 'open':
            lines.push(indent(depth) + (statement.value ? statement.value + ' {' : '{'))
            depth++
            break
        case 'close':
            depth = Math.max(depth - 1, 0)
            lines.push(indent(depth) + '}')
            if (depth === 0) lines.push('')
            break
        case 'comment':
            lines.push(indent(depth) + statement.value)
            break
        default:
            lines.push(indent(depth) + cssDeclaration(statement.value, ' ') + ';')
        }
    }
    return lines.join('\n').trim()
}

// "a , b > c" -> "a,b>c". Preludes with strings are left alone.
function cssMinPrelude(value) {
    return /["']/.test(value) ? value : value.replace(/\s*([,>])\s*/g, '$1')
}

function cssmin(text) {
    let out = ''
    for (const statement of cssStatements(String(text))) {
        switch (statement.kind) {
        case 'open': out += cssMinPrelude(statement.value) + '{'; break
        case 'close': out = out.replace(/;$/, '') + '}'; break
        case 'comment': break
        default: out += cssDeclaration(statement.value, '') + ';'
        }
    }
    return out.replace(/;$/, '')
}

// ---------------------------------------------------------------- SQL

// Splits SQL into words, literals, comments and punctuation. Strings ('it''s'),
// quoted identifiers ("a", `a`, [a]), dollar quotes ($$...$$) and comments are
// single tokens and are never changed.
function sqlTokens(text) {
    const tokens = []
    let i = 0
    const quoted = (close, type) => {
        let j = i + 1
        while (j < text.length) {
            if (text[j] === close) {
                if (text[j + 1] === close) { j += 2; continue }
                break
            }
            j++
        }
        tokens.push({ type, value: text.slice(i, j + 1) })
        i = j + 1
    }
    while (i < text.length) {
        const c = text[i]
        const rest = text.slice(i)
        let match
        if (/\s/.test(c)) {
            i++
        } else if (rest.startsWith('--')) {
            const end = text.indexOf('\n', i)
            const stop = end === -1 ? text.length : end
            tokens.push({ type: 'lineComment', value: text.slice(i, stop).trimEnd() })
            i = stop
        } else if (rest.startsWith('/*')) {
            const end = text.indexOf('*/', i + 2)
            const stop = end === -1 ? text.length : end + 2
            tokens.push({ type: 'comment', value: text.slice(i, stop) })
            i = stop
        } else if (c === "'") {
            quoted("'", 'string')
        } else if (c === '"') {
            quoted('"', 'word')
        } else if (c === '`') {
            quoted('`', 'word')
        } else if (c === '[') {
            quoted(']', 'word')
        } else if ((match = /^\$([A-Za-z_]\w*)?\$/.exec(rest))) {
            const end = text.indexOf(match[0], i + match[0].length)
            const stop = end === -1 ? text.length : end + match[0].length
            tokens.push({ type: 'string', value: text.slice(i, stop) })
            i = stop
        } else if ((match = /^[\p{L}_@#][\p{L}\p{N}_$@#]*/u.exec(rest))) {
            tokens.push({ type: 'word', value: match[0] })
            i += match[0].length
        } else if ((match = /^(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?/.exec(rest))) {
            tokens.push({ type: 'word', value: match[0] })
            i += match[0].length
        } else if ((match = /^(<=|>=|<>|!=|::|\|\||->>|->|[-+*\/%=<>!~^&|:?])/.exec(rest))) {
            tokens.push({ type: 'operator', value: match[0] })
            i += match[0].length
        } else {
            tokens.push({ type: c, value: c })
            i++
        }
    }
    return tokens
}

// Keywords that start a new line at the current query's depth.
const sqlClauses = [
    'SELECT', 'FROM', 'WHERE', 'GROUP BY', 'ORDER BY', 'HAVING', 'LIMIT', 'OFFSET',
    'UNION ALL', 'UNION', 'INTERSECT', 'EXCEPT', 'INSERT INTO', 'VALUES', 'UPDATE', 'SET',
    'DELETE FROM', 'RETURNING', 'WITH', 'WINDOW', 'ON CONFLICT',
    'LEFT OUTER JOIN', 'RIGHT OUTER JOIN', 'FULL OUTER JOIN', 'LEFT JOIN', 'RIGHT JOIN',
    'FULL JOIN', 'INNER JOIN', 'CROSS JOIN', 'JOIN'
].map(clause => clause.split(' '))

// Keywords that start a new line one level deeper than the clause.
const sqlConditions = ['ON', 'AND', 'OR']

// Clauses whose top-level commas each start a new line.
const sqlListClauses = ['SELECT', 'SET', 'GROUP BY', 'ORDER BY']

// Words after which "(" keeps a space: "IN (1, 2)" but "count(*)".
const sqlSpacedBeforeParen = new Set(['IN', 'AS', 'ON', 'AND', 'OR', 'NOT', 'EXISTS', 'VALUES',
    'INTO', 'FROM', 'JOIN', 'WHERE', 'SELECT', 'OVER', 'USING', 'THEN', 'ELSE', 'WHEN', 'ANY', 'ALL',
    'UNION', 'RETURNING', 'WITH', 'HAVING', 'BY', 'SET', 'IS', 'LIKE', 'BETWEEN'])

function matchClause(tokens, i) {
    for (const words of sqlClauses) {
        if (words.every((word, k) => tokens[i + k] && tokens[i + k].type === 'word' &&
                tokens[i + k].value.toUpperCase() === word)) {
            return words
        }
    }
    return null
}

function sql(text) {
    const tokens = sqlTokens(String(text))
    let out = ''
    // One frame per open parenthesis; subqueries get their own depth.
    const frames = [{ subquery: true, depth: 0, clause: null }]
    const frame = () => frames[frames.length - 1]
    const newline = depth => {
        const end = out.trimEnd()
        out = end + (end.endsWith(';') ? '\n\n' : '\n') + indent(depth)
    }
    const lineDepth = () => out.slice(out.lastIndexOf('\n') + 1).match(/^ */)[0].length / indentUnit.length
    let previous = null

    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i]
        const upper = token.type === 'word' ? token.value.toUpperCase() : null
        const current = frame()
        const clause = current.subquery ? matchClause(tokens, i) : null

        if (clause) {
            if (out.trim()) newline(current.depth)
            out += tokens.slice(i, i + clause.length).map(t => t.value).join(' ')
            current.clause = clause.join(' ')
            i += clause.length - 1
            previous = tokens[i]
            continue
        }

        if (current.subquery && sqlConditions.includes(upper) && !(upper === 'AND' && current.between)) {
            newline(current.depth + 1)
            out += token.value
            previous = token
            continue
        }

        if (token.type === '(') {
            const subquery = tokens[i + 1] && tokens[i + 1].type === 'word' &&
                ['SELECT', 'WITH'].includes(tokens[i + 1].value.toUpperCase())
            const spaced = previous && (previous.type === 'word' && sqlSpacedBeforeParen.has(previous.value.toUpperCase()) ||
                previous.type === 'operator' || previous.type === ',')
            if (previous && spaced) out += ' '
            out += '('
            // A subquery is indented one level past the line that opens it.
            const opener = lineDepth()
            frames.push({ subquery, depth: subquery ? opener + 1 : current.depth, opener, clause: null })
            previous = token
            continue
        }

        if (token.type === ')') {
            if (frames.length > 1) {
                const closing = frames.pop()
                if (closing.subquery) newline(closing.opener)
            }
            out += ')'
            previous = token
            continue
        }

        if (token.type === ',') {
            out += ','
            if (current.subquery && sqlListClauses.includes(current.clause)) newline(current.depth + 1)
            previous = token
            continue
        }

        if (token.type === ';') {
            out = out.trimEnd() + ';'
            frames.length = 1
            frames[0].clause = null
            previous = null
            continue
        }

        if (token.type === '.' || (previous && previous.type === '.')) {
            out += token.value
            previous = token
            continue
        }

        if (upper === 'BETWEEN') current.between = true
        if (upper === 'AND' && current.between) current.between = false

        const glued = !previous || previous.type === '(' || out.endsWith('\n') || /\n\s*$/.test(out)
        if (!glued) out += ' '
        out += token.value
        if (token.type === 'lineComment') newline(current.depth + (current.clause ? 1 : 0))
        previous = token
    }

    return out.replace(/[ \t]+$/gm, '').trim()
}

function sqlmin(text) {
    let out = ''
    let previous = null
    for (const token of sqlTokens(String(text))) {
        if (token.type === 'lineComment' || token.type === 'comment') continue
        const call = token.type === '(' && previous && previous.type === 'word' &&
            !sqlSpacedBeforeParen.has(previous.value.toUpperCase())
        const tight = call || token.type === ',' || token.type === ')' || token.type === ';' || token.type === '.' ||
            previous === null || previous.type === '(' || previous.type === '.'
        if (!tight) out += ' '
        out += token.value
        previous = token
    }
    return out
}

module.exports = { xml, xmlmin, css, cssmin, sql, sqlmin }
