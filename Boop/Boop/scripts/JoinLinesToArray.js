/**
	{
		"api":1,
		"name":"Join Lines Into A JS Array",
		"description":"Joins all lines into an array format: [\"line 1\", \"line 2\"].",
		"author":"Kris Linquist",
		"icon":"collapse",
		"tags":"join, array",
		"bias": -0.1
	}
**/

function main(input) {
    const txt = input.text.split('\n');
    const newDataArr = [];
    for (const rawLine of txt){
        const line = rawLine.trim();
        if (line.match(/^[-+]?[0-9]*\.?[0-9]+$/)){
            newDataArr.push(Number(line));
        } else {
            newDataArr.push(line);
        }
    }
    input.text = JSON.stringify(newDataArr);
}
