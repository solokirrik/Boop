/**
	{
		"api":1,
		"name":"Fahrenheit to Celsius",
		"description":"Convert temp from ºF to ºC.",
		"author":"armchairdeity",
		"icon":"translation",
		"tags":"temperature,celsius,centigrade,fahrenheit,convert"
	}
**/

function main(state) {
	const fahrenheit = parseFloat(state.text);

	if (isNaN(fahrenheit)) {
		state.postError("Please enter a temperature in ºF");
		return;
	}

	state.text = `${fahrenheit}°F = ${(((fahrenheit - 32) * 5) / 9).toFixed(2)}°C`;
}
