// We're using a global variable to store the number of occurrences
var PS_SearchResultCount = 0;

// helper function, recursively searches in elements and their child nodes
function PS_HighlightAllOccurencesOfStringForElement(element,keyword) {
	if (element) {
		if (element.nodeType == 3) {        // Text node
			while (true) {
				var value = element.nodeValue;  // Search for keyword in text node
				var idx = value.toLowerCase().indexOf(keyword);
				
				if (idx < 0) break;             // not found, abort
				
				var span = document.createElement("span");
				var text = document.createTextNode(value.substr(idx,keyword.length));
				span.appendChild(text);
				span.setAttribute("class","PocketSwordHighlight");
				span.style.backgroundColor="yellow";
				span.style.color="black";
				text = document.createTextNode(value.substr(idx+keyword.length));
				element.deleteData(idx, value.length - idx);
				var next = element.nextSibling;
				element.parentNode.insertBefore(span, next);
				element.parentNode.insertBefore(text, next);
				element = text;
				PS_SearchResultCount++;	// update the counter
			}
		} else if (element.nodeType == 1) { // Element node
			if (element.style.display != "none" && element.nodeName.toLowerCase() != 'select') {
				for (var i=element.childNodes.length-1; i>=0; i--) {
					PS_HighlightAllOccurencesOfStringForElement(element.childNodes[i],keyword);
				}
			}
		}
	}
}

// the main entry point to start the search
function PS_HighlightAllOccurencesOfString(keyword) {
	PS_RemoveAllHighlights();
	PS_HighlightAllOccurencesOfStringForElement(document.body, keyword.toLowerCase());
}

// helper function, recursively removes the highlights in elements and their childs
function PS_RemoveAllHighlightsForElement(element) {
	if (element) {
		if (element.nodeType == 1) {
			if (element.getAttribute("class") == "PocketSwordHighlight") {
				var text = element.removeChild(element.firstChild);
				element.parentNode.insertBefore(text,element);
				element.parentNode.removeChild(element);
				return true;
			} else {
				var normalize = false;
				for (var i=element.childNodes.length-1; i>=0; i--) {
					if (PS_RemoveAllHighlightsForElement(element.childNodes[i])) {
						normalize = true;
					}
				}
				if (normalize) {
					element.normalize();
				}
			}
		}
	}
	return false;
}

// the main entry point to remove the highlights
function PS_RemoveAllHighlights() {
	PS_SearchResultCount = 0;
	PS_RemoveAllHighlightsForElement(document.body);
}