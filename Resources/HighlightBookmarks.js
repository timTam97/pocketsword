function PS_HighlightVerseWithHexColour(verse,colour) {
	var elementToHighlight = document.getElementById("vvv"+verse);
	elementToHighlight.style.backgroundColor = colour;
	elementToHighlight.style.color = "black";
	//elementToHighlight.style.opacity = 0.8;
}

function PS_RemoveHighlights(verseMax,fontColour) {
	for (var i=1; i < verseMax; i++) {
		var curobj = document.getElementById("vvv"+i);
		curobj.style.backgroundColor = "transparent";
		curobj.style.color = fontColour;
	}
}