function PS_HighlightVerseWithHexColour(verse,colour) {
	var elementToHighlight = document.getElementById("vvv"+verse);
	elementToHighlight.style.backgroundColor = colour;
}

function PS_RemoveHighlights(verseMax) {
	for (var i=1; i < verseMax; i++) {
		var curobj = document.getElementById("vvv"+i);
		curobj.style.backgroundColor = "transparent";
	}
}