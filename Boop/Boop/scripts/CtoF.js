/**
	{
		"api":1,
		"name":"Celsius to Fahrenheit",
		"description":"Convert temp from ºC to ºF.",
		"author":"armchairdeity",
		"icon":"translation",
		"tags":"temperature,celsius,centigrade,fahrenheit,convert"
	}
**/

function main(state) {
	const celsius = parseFloat(state.text);

	if (isNaN(celsius)) {
		state.postError("Please enter a temperature in ºC");
		return;
	}

	state.text = `${celsius}°C = ${((celsius * 9) / 5 + 32).toFixed(2)}°F`;
}
