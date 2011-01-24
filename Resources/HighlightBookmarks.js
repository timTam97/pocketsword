function PS_HighlightVerseWithHexColour(verse,colour) {
	var elementToHighlight = document.getElementById("vvv"+verse);
	elementToHighlight.style.backgroundColor = colour;
}