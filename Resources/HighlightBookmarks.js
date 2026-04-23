function PS_HighlightVerseWithHexColour(verse,colour) {
	var elementToHighlight = document.getElementById("vvv"+verse);
	elementToHighlight.style.backgroundColor = colour;
	elementToHighlight.style.color = "black";
}

function PS_RemoveHighlights(verseMax) {
	for (var i=1; i < verseMax; i++) {
		var curobj = document.getElementById("vvv"+i);
		curobj.style.backgroundColor = "";
		curobj.style.color = "";
	}
}