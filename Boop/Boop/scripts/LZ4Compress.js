/**
	{
		"api":1,
		"name":"LZ4 Compress",
		"description":"Compresses your text into an LZ4 frame, output as base64.",
		"author":"Kirill Tishenkov",
		"icon":"collapse",
		"tags":"lz4,compress"
	}
**/

const { lz4 } = require('@boop/compression')

function main(state) {
	try {
		state.text = lz4(state.text)
	} catch (error) {
		state.postError(error.message)
	}
}
