/**
	{
		"api":1,
		"name":"Gzip Decompress",
		"description":"Decompresses base64 or hex gzip, zlib or DEFLATE data.",
		"author":"Kirill",
		"icon":"metamorphose",
		"tags":"gzip,gunzip,zlib,deflate,inflate,decompress,uncompress,unzip"
	}
**/

const { gunzip } = require('@boop/compression')

function main(state) {
	try {
		const result = gunzip(state.text)
		state.text = result.text
		if (result.binary) {
			state.postInfo('The output isn\'t text, so it\'s shown as hex')
		}
	} catch (error) {
		state.postError(error.message)
	}
}
