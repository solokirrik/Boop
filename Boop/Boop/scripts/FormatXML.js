/**
	{
		"api":1,
		"name":"Format XML",
		"description":"Formats XML documents.",
		"author":"Ivan",
		"icon":"broom",
		"tags":"html,prettify,clean,indent",
        "bias": -0.1
	}
**/

const { xml } = require('@boop/format')


function main(state) {
	try {
		state.text = xml(state.text)
	} catch (error) {
		state.postError(error.message)
	}
}
