/**
	{
		"api":1,
		"name":"LZ4 Compress (Size-Prefixed Block)",
		"description":"Compresses your text into a raw LZ4 block after a 4-byte size, output as base64.",
		"author":"Kirill Tishenkov",
		"icon":"collapse",
		"tags":"lz4,compress,block,raw,python,size"
	}
**/

const { lz4Block } = require('@boop/compression')

function main(state) {
	try {
		state.text = lz4Block(state.text)
	} catch (error) {
		state.postError(error.message)
	}
}
