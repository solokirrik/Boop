/**
	{
		"api":1,
		"name":"Gzip Compress",
		"description":"Gzips your text and outputs it as base64.",
		"author":"Kirill",
		"icon":"collapse",
		"tags":"gzip,zlib,deflate,compress,zip"
	}
**/

const { gzip } = require('@boop/compression')

function main(state) {
	try {
		state.text = gzip(state.text)
	} catch (error) {
		state.postError(error.message)
	}
}
