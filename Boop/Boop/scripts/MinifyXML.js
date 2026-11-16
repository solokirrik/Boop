/**
	{
		"api":1,
		"name":"Minify XML",
		"description":"Minifies XML documents.",
		"author":"Ivan",
		"icon":"broom",
		"tags":"html,minify,clean,indent",
        "bias": -0.1
	}
**/

const { xmlmin } = require('@boop/format')


function main(state) {
	try {
		state.text = xmlmin(state.text)
	} catch (error) {
		state.postError(error.message)
	}
}
