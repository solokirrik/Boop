/**
	{
		"api":1,
		"name":"LZ4 Decompress",
		"description":"Decompresses base64 or hex LZ4 frames or raw LZ4 blocks.",
		"author":"Kirill Tishenkov",
		"icon":"metamorphose",
		"tags":"lz4,decompress,uncompress"
	}
**/

const { lz4Decompress } = require('@boop/compression')

function main(state) {
	try {
		const result = lz4Decompress(state.text)
		state.text = result.text
		if (result.binary) {
			state.postInfo('The output isn\'t text, so it\'s shown as hex')
		}
	} catch (error) {
		state.postError(error.message)
	}
}
