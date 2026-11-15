/**
	{
		"api":1,
		"name":"Timestamp to Date",
		"description":"Converts Unix timestamps (s, ms, µs, ns) to local dates",
		"author":"solokirrik",
		"icon":"watch",
		"tags":"date,time,calendar,unix,timestamp,epoch,format,millis"
	}
**/

// Each line holding a single timestamp is converted, other lines are kept.
// The unit is guessed from the number of integer digits:
//   up to 11 -> seconds, 12-14 -> milliseconds, 15-17 -> microseconds, 18+ -> nanoseconds
// Output: YYYY-MM-DD HH:mm:ss[.SSS] ±HH:MM (local time)

const TIMESTAMP = /^\s*(-?)(\d+)(?:\.(\d+))?\s*$/

function main(input) {
	let converted = 0

	const lines = input.text.split("\n").map(line => {
		const date = parseTimestamp(line)
		if (!date) {
			return line
		}
		converted++
		return formatDate(date)
	})

	if (converted === 0) {
		input.postError("No timestamps found")
		return
	}

	input.text = lines.join("\n")
}

function parseTimestamp(line) {
	const match = TIMESTAMP.exec(line)
	if (!match) {
		return null
	}

	const [, sign, intPart, fraction = ""] = match
	const digits = intPart.replace(/^0+(?=\d)/, "").length
	const value = Number(`${sign}${intPart}.${fraction || "0"}`)

	let millis
	if (digits <= 11) {
		millis = value * 1000
	} else if (digits <= 14) {
		millis = value
	} else if (digits <= 17) {
		millis = value / 1e3
	} else {
		millis = value / 1e6
	}

	const date = new Date(Math.round(millis))
	return isNaN(date.getTime()) ? null : date
}

function pad(number, length = 2) {
	return String(Math.abs(number)).padStart(length, "0")
}

function formatDate(date) {
	const ms = date.getMilliseconds()
	const offset = -date.getTimezoneOffset()
	const sign = offset >= 0 ? "+" : "-"

	return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
		` ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}` +
		(ms ? `.${pad(ms, 3)}` : "") +
		` ${sign}${pad(Math.floor(Math.abs(offset) / 60))}:${pad(Math.abs(offset) % 60)}`
}
