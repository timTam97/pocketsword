//
//  PSChapterNavigationJS.swift
//  PocketSword
//
//  The chapter-navigation script block that goes into every rendered chapter page:
//  the `versepos` offset table, the scroll-to-verse helpers, and the `window.onload`
//  that builds the table and reports it back to the app through the
//  `pocketsword:` URL scheme.
//
//  SWORD_REMOVAL_PLAN.md Phase 5 step 3. This is a **move, not a copy** across the
//  phase, but it has to be staged: the byte-equality assertion needs both sides to
//  exist at once. So this commit adds the Swift version and points PSContentReader
//  at it, `PSChapterNavigationJSTests` asserts the two produce identical bytes, and
//  step 7 deletes `+[SwordModule chapterNavigationJSWithEntryCount:extraJS:]` along
//  with the rest of the bridge — and the assertion with it.
//
//  There is no SWORD dependency here and never was: it is 4,022 bytes of pure JS
//  plus five substitutions. That is exactly why it could be extracted verbatim in
//  Phase 3 rather than reimplemented, and why the reader has been calling the Obj-C
//  copy ever since instead of carrying a duplicate that nothing would keep in sync.
//
//  === Why the odd shape ===
//
//  The literal below is a list of chunks joined, rather than one string with
//  interpolations, because it was **generated mechanically from the Obj-C format
//  string's own bytes** rather than transcribed. The original is a 124-line C string
//  literal using backslash-newline line splicing with tab indentation inside it;
//  hand-retyping that is exactly the kind of thing that silently loses a tab or a
//  `\n` and produces JS that still runs but scrolls to the wrong offset. The chunk
//  boundaries are the substitution points, so what is asserted byte-equal is also
//  what is readable as "literal, value, literal".
//
//  Two quirks preserved deliberately, both visible at the end of the string:
//
//   * `-->` is followed **directly** by tabs and `</script>`, with no newline —
//     `@"…\n-->\` then a spliced continuation line. It looks like a typo and is
//     kept because it is in the bytes the fixtures were captured against.
//   * All four `%ld` take the **same** `entryCount`. Two feed `currentVerse()`'s
//     loop bounds and two feed `resetArrays()`'s, and since entryCount is the loop
//     counter rather than a verse count (see PSChapterAssembler), the arrays are
//     sized one larger than the verse count. That is what the anchors `vv{i}` are
//     numbered against, so it is correct as written.
//

import Foundation

enum PSChapterNavigationJS {

    /// The `<script>` block for a chapter with `entryCount` entries.
    ///
    /// - Parameters:
    ///   - entryCount: `-chapterBodyHTML:`'s loop counter — NOT a verse count. It
    ///     bounds the `versepos` array and both scan loops, and matches the `vv{i}`
    ///     anchor numbering the assembler emitted.
    ///   - extraJS: injected inside `window.onload`, immediately after
    ///     `resetArrays()`. This is how the render path asks the page to restore a
    ///     scroll position or jump to a verse on first paint.
    static func script(entryCount: Int, extraJS: String) -> String {
        // `%ld` took `(long)entryCount`, so the rendering must be the plain decimal
        // form with no grouping separators — which is what Int's default
        // description gives, and is why this does not go through a NumberFormatter.
        let count = String(entryCount)
        let extra = extraJS
        return [
            "<script type=\"text/javascript\">\n<!--\n\t\t\t\t\tvar versepos;\n\t\t\t\t\tvar det_loc_poll;\n\t\t\t\t\tvar lastSentVerse;\n\t\t\t\t\tfunction findPosition(foo) {\n\t\t\t\t\t\tvar curtop = 0;\n\t\t\t\t\t\tfor (var obj = foo; obj != null; obj = obj.offsetParent) {\n\t\t\t\t\t\t\tcurtop += obj.offsetTop;\n\t\t\t\t\t\t}\n\t\t\t\t\t\treturn curtop;\n\t\t\t\t\t}\n\t\t\t\t\tfunction currentVerse() {\n\t\t\t\t\t\tvar now = window.pageYOffset;\n\t\t\t\t\t\tif(now < 5) return 1;\n\t\t\t\t\t\tvar g = (",
            count,
            "-1);\n\t\t\t\t\t\tfor(var i=1;i<",
            count,
            ";i++) {\n\t\t\t\t\t\t\tif(versepos[i] > now) {\n\t\t\t\t\t\t\t\tg = ((i == 1) ? 1 : (i - 1));\n\t\t\t\t\t\t\t\tbreak;\n\t\t\t\t\t\t\t}\n\t\t\t\t\t\t}\n\t\t\t\t\t\tif (g == 1) return 1;\n\t\t\t\t\t\tfor(var i=g;i>1;i--) {\n\t\t\t\t\t\t\tif(versepos[i] != versepos[i-1])\n\t\t\t\t\t\t\t\treturn i;\n\t\t\t\t\t\t}\n\t\t\t\t\t\treturn 1;\n\t\t\t\t\t}\n\t\t\t\t\tfunction execute(url) {\n\t\t\t\t\t\tvar iframe = document.createElement(\"IFRAME\");\n\t\t\t\t\t\tiframe.setAttribute(\"src\", url);\n\t\t\t\t\t\tdocument.documentElement.appendChild(iframe);\n\t\t\t\t\t\tiframe.parentNode.removeChild(iframe);\n\t\t\t\t\t\tiframe = null;\n\t\t\t\t\t}\n\t\t\t\t\tfunction detLoc() {\n\t\t\t\t\t\tvar verseToSend = currentVerse();\n\t\t\t\t\t\tif(verseToSend != lastSentVerse) {\n\t\t\t\t\t\t\texecute(\"pocketsword:currentverse:\" + verseToSend + \":\" + window.pageYOffset + \":\" + versepos[verseToSend]);\n\t\t\t\t\t\t\tlastSentVerse = verseToSend;\n\t\t\t\t\t\t}\n\t\t\t\t\t}\n\t\t\t\t\tfunction startDetLocPoll() {\n\t\t\t\t\t\tstopDetLocPoll();//we don't want this running more than once, so stop previous polls first...\n\t\t\t\t\t\t/*det_loc_poll = setInterval(\"detLoc()\", 1000);*/\n\t\t\t\t\t}\n\t\t\t\t\tfunction stopDetLocPoll() {\n\t\t\t\t\t\tclearInterval(det_loc_poll);\n\t\t\t\t\t}\n\t\t\t\t\tfunction scrollToVerse(verse) {\n\t\t\t\t\t\tsetTimeout(function() { _scrollToVerse(verse); }, 250);\n\t\t\t\t\t}\n\t\t\t\t\tfunction scrollToYOffset(iTargetY) {\n\t\t\t\t\t\tiTargetY = iTargetY < 0 ? 0 : iTargetY;\n\t\t\t\t\t\tvar frameInterval = 20; // 20 milliseconds per frame\n\t\t\t\t\t\tvar totalTime = 750;\n\t\t\t\t\t\tvar startY = window.pageYOffset;\n\t\t\t\t\t\tvar d = iTargetY - startY; // total distance to scroll\n\t\t\t\t\t\tvar freq = Math.PI / (2 * totalTime); // frequency\n\t\t\t\t\t\tvar startTime = new Date().getTime();\n\t\t\t\t\t\tvar tmr = setInterval(\n\t\t\t\t\t\t\tfunction () {\n\t\t\t\t\t\t\t\t// check the time that has passed from the last frame\n\t\t\t\t\t\t\t\tvar elapsedTime = new Date().getTime() - startTime;\n\t\t\t\t\t\t\t\tif (elapsedTime < totalTime) { // are we there yet?\n\t\t\t\t\t\t\t\t\tvar f = Math.abs(Math.sin(elapsedTime * freq));\n\t\t\t\t\t\t\t\t\twindow.scrollTo(0, Math.round(f*d) + startY);\n\t\t\t\t\t\t\t\t} else {\n\t\t\t\t\t\t\t\t\tclearInterval(tmr);\n\t\t\t\t\t\t\t\t\twindow.scrollTo(0, iTargetY);\n\t\t\t\t\t\t\t\t}\n\t\t\t\t\t\t\t}\n\t\t\t\t\t\t\t, frameInterval);\n\t\t\t\t\t}\n\t\t\t\t\tfunction scrollToPosition(position) {\n\t\t\t\t\t\tsetTimeout(\"window.scrollTo(0, \"+position+\")\", 250);\n\t\t\t\t\t\t//setTimeout(\"scrollToYOffset(\"+position+\")\", 250);\n\t\t\t\t\t}\n\t\t\t\t\tfunction _scrollToVerse(verse) {\n\t\t\t\t\t\tverse = parseInt(verse, 10);\n\t\t\t\t\t\tif(isNaN(verse) || verse <= 1) {\n\t\t\t\t\t\t\twindow.scrollTo(0,0);\n\t\t\t\t\t\t\t//scrollToYOffset(0);\n\t\t\t\t\t\t} else if(!versepos) {\n\t\t\t\t\t\t\treturn;\n\t\t\t\t\t\t} else if(typeof versepos[verse] != \"undefined\" && versepos[verse] != 0) {\n\t\t\t\t\t\t\twindow.scrollTo(0, versepos[verse]);\n\t\t\t\t\t\t\t//scrollToYOffset(versepos[verse]);\n\t\t\t\t\t\t} else {\n\t\t\t\t\t\t\tfor(var ii = verse; ii > 0; ii--) {\n\t\t\t\t\t\t\t\tif(typeof versepos[ii] != \"undefined\" && versepos[ii] != 0) {\n\t\t\t\t\t\t\t\t\twindow.scrollTo(0, versepos[ii]);\n\t\t\t\t\t\t\t\t\t//scrollToYOffset(versepos[ii]);\n\t\t\t\t\t\t\t\t\tbreak;\n\t\t\t\t\t\t\t\t}\n\t\t\t\t\t\t\t}\n\t\t\t\t\t\t}\n\t\t\t\t\t}\n\t\t\t\t\tfunction resetArrays() {\n\t\t\t\t\t\tversepos = null;\n\t\t\t\t\t\tversepos = new Array(",
            count,
            ");\n\t\t\t\t\t\tvar tmpstr = \"arraydump:\";\n\t\t\t\t\t\tfor (var i=1; i < ",
            count,
            "; i++) {\n\t\t\t\t\t\t\tvar curobj = document.getElementById(\"vv\"+i);\n\t\t\t\t\t\t\tversepos[i] = findPosition(curobj);\n\t\t\t\t\t\t\tif((i != 1) && (versepos[i] == 0)) {\n\t\t\t\t\t\t\t\tversepos[i] = versepos[i-1];\n\t\t\t\t\t\t\t}\n\t\t\t\t\t\t\ttmpstr += versepos[i] + \":\";\n\t\t\t\t\t\t}\n\t\t\t\t\t\t//document.location = tmpstr;\n\t\t\t\t\t\texecute(tmpstr);\n\t\t\t\t\t\tlastSentVerse = -1;\n\t\t\t\t\t}\n\t\t\t\t\t//document.addEventListener(\"touchmove\", detLoc, false);\n\t\t\t\t\t//document.addEventListener(\"scroll\", detLoc, false);\n\t\t\t\t\twindow.onload = function() {\n\t\t\t\t\t\tdocument.documentElement.style.webkitTouchCallout = \"none\";\n\t\t\t\t\t\tresetArrays()\n\t\t\t\t\t\t",
            extra,
            "\n\t\t\t\t\t\t//detLoc();\n\t\t\t\t\t}\n-->\t\t\t\t\t</script>\n"
        ].joined()
    }
}
