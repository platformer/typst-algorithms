// counter to track the number of algo elements
// used as an id when accessing:
//   _algo-comment-lists
#let _algo-id-ckey = "_algo-id"

// state value for storing current comment-prefix passed to algo
#let _algo-comment-prefix = state("_algo-comment-prefix", [])

// state value for storing current comment-styles passed to algo
#let _algo-comment-styles = state("_algo-comment-styles", x => [#x])

// counter to track the number of lines in an algo element
#let _algo-line-ckey = "_algo-line"

// state value to track the current indent level in an algo element
#let _algo-indent-level = state("_algo-indent-level", 0)

// state value to track whether the current context is an algo element
#let _algo-in-algo-context = state("_algo-in-algo-context", false)

// state value for storing algo comments
// dictionary that maps algo ids (as strings) to a dictionary that maps
//   line indexes (as strings) to the comment appearing on that line
#let _algo-comment-dicts = state("_algo-comment-dicts", (:))

// list of default keywords that will be highlighted by keyword-styles
#let _algo-default-keywords = (
  // branch delimiters
  "if",
  "else",
  "then",

  // loop delimiters
  "while",
  "for",
  "repeat",
  "do",
  "until",

  // general delimiters
  ":",
  "end",

  // conditional expressions
  "and",
  "or",
  "not",
  "in",

  // loop conditions
  "to",
  "down",

  // misc
  "let",
  "return",
  "goto",
).map(kw => {
  // add uppercase words to list
  if kw.starts-with(regex("\w")) {
    (kw, str.from-unicode(str.to-unicode(kw.first()) - 32) + kw.slice(1))
  } else {
    (kw,)
  }
}).flatten()

// constants for measuring text height
#let _alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
#let _numerals = "0123456789"
#let _special-characters = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
#let _alphanumerics = _alphabet + _numerals
#let _ascii = _alphanumerics + _special-characters


// Makes assertion where message is automatically prepended with "algo: ".
//
// Parameters:
//   condition: Condition to assert is true.
//   message: Message to return if asssertion fails.
#let _algo-assert(condition, message: "") = {
  assert(condition, message: "algo: " + message)
}


// Given data about a line in an algo or code, creates the
//   indent guides that should appear on that line.
//
// Parameters:
//   stroke: Stroke for drawing indent guides.
//   offset: Horizontal offset of indent guides.
//   indent-level: The indent level on the given line.
//   indent-size: The absolute length of a single indent.
//   row-height: The absolute height of the containing row of the given line.
//   block-inset: The absolute inset of the block containing all the lines.
//     Used when determining the length of an indent guide that appears
//     on the top or bottom of the block.
//   row-gutter: The absolute gap between lines.
//     Used when determining the length of an indent guide that appears
//     next to other lines.
//   is-first-line: Whether the given line is the first line in the block.
//   is-last-line: Whether the given line is the last line in the block.
//     If so, the length of the indent guide will depend on block-inset.
#let _indent-guides(
  stroke,
  offset,
  indent-level,
  indent-size,
  row-height,
  block-inset,
  row-gutter,
  is-first-line,
  is-last-line,
) = {
  let stroke-width = stroke.thickness

  // lines are drawn relative to the top left of the bounding box for text
  // backset determines how far up the starting point should be moved
  let backset = if is-first-line {
    0pt
  } else {
    row-gutter / 2
  }

  // determine how far the line should extend
  let stroke-length = backset + row-height + (
    if is-last-line {
      calc.min(block-inset / 2, row-height / 4)
    } else {
      row-gutter / 2
    }
  )

  // draw the indent guide for each indent level on the given line
  for j in range(indent-level) {
    box(
      height: row-height,
      width: 0pt,
      align(
        start + top,
        place(
          dx: indent-size * j + stroke-width / 2 + 0.5pt + offset,
          dy: -backset,
          line(
            length: stroke-length,
            angle: 90deg,
            stroke: stroke
          )
        )
      )
    )
  }
}


// Returns header to be displayed above algorithm content.
//
// Parameters:
//   header: Algorithm header. Overrides title and parameters.
//   title: Algorithm title. Ignored if header is not none.
//   Parameters: Array of parameters. Ignored if header is not none.
#let _build-algo-header(header, title, parameters) = {
  if header != none {
    header
  } else {
    set align(start)

    if title != none {
      set text(1.1em)

      if type(title) == str {
        underline(smallcaps(title))
      } else {
        title
      }

      if parameters.len() == 0 {
        $()$
      }
    }

    if parameters != () {
      set text(1.1em)

      $($

      parameters.map(param => if type(param) == str {
        math.italic(param)
      } else {
        param
      }).join([, ])

      $)$
    }

    if title != none or parameters != () {
      [:]
    }
  }
}


// Create indent guides for a given line of an algo element.
// Given the content of the line, calculates size of the content
//   and creates indent guides of sufficient length.
//
// Parameters:
//   indent-guides: Stroke for drawing indent guides.
//   indent-guides-offset: Horizontal offset of indent guides.
//   content: The main text that appears on the given line.
//   line-index: The 0-based index of the given line.
//   num-lines: The total number of lines in the current element.
//   indent-level: The indent level at the given line.
//   indent-size: The indent size used in the current element.
//   block-inset: The inset of the current element.
//   row-gutter: The row-gutter of the current element.
//   main-text-styles: Styling function to apply to the main algorithm text.
//   comment-styles: Styling function to apply to comments.
//   line-number-styles: Styling function to apply to line numbers.
#let _algo-indent-guides(
  indent-guides,
  indent-guides-offset,
  content,
  line-index,
  num-lines,
  indent-level,
  indent-size,
  block-inset,
  row-gutter,
  main-text-styles,
  comment-styles,
  line-number-styles,
) = { locate(loc => style(styles => {
  let id-str = str(counter(_algo-id-ckey).at(loc).at(0))
  let comment-dicts = _algo-comment-dicts.final(loc)
  let comment-content = comment-dicts.at(id-str, default: (:))
                                     .at(str(line-index), default: [])

  // heuristically determine the height of the containing table row
  let row-height = calc.max(
    // height of main content
    measure(
      main-text-styles(
        _alphanumerics + content
      ),
      styles
    ).height,

    // height of comment
    measure(
      comment-styles(comment-content),
      styles
    ).height,

    // height of line numbers
    measure(
      line-number-styles(line-index),
      styles
    ).height
  )

  // TODO: WHY?!
  /*// converting input parameters to absolute lengths
  let indent-size-abs = measure(
    rect(width: indent-size),
    styles
  ).width

  let block-inset-abs = measure(
    rect(width: block-inset),
    styles
  ).width

  let row-gutter-abs = measure(
    rect(width: row-gutter),
    styles
  ).width
  */

  let is-first-line = line-index == 0
  let is-last-line = line-index == num-lines - 1

  // display indent guides at the current line
  _indent-guides(
    indent-guides,
    indent-guides-offset,
    indent-level,
    indent-size,
    row-height,
    block-inset,
    row-gutter,
    is-first-line,
    is-last-line
  )
}))}

// Returns the regex for the keyword show rule, using one regex for all together
//
// Parameters:
//   keywords: List of terms
#let _compute-keyword-regex(keywords) = {
  // distinguish between 4 cases:
  // - word boundaries on both sides, e.g. while
  // - word boundary only left,       e.g. let*
  // - word boundary only right,      e.g. $for
  // - no word boundaries,            e.g. :
  let char-regex = regex("\w")
  let str-keywords = keywords.filter(
    kw => type(kw) == str
  ).map(
    kw => kw.trim()
  ).map(kw =>
    if kw.starts-with(char-regex) {
      "\b{start}" + kw + if kw.ends-with(char-regex) { "\b{end}" }
    } else {
      kw + if kw.ends-with(char-regex) { "\b{end}" }
    }
  ).join("|")
  
  (regex(str-keywords), keywords.filter(kw => type(kw) != str))
}

// Returns the content with a keyword show rule applied to a text element
//
// Parameters:
//   kwr: regex keyword(s)
//   keyword-styles: as always
//   child: text element to apply keyword filtered styling to
#let _single-content-replacer(kwr, keyword-styles, child) = {
  show kwr: kw => keyword-styles(kw)
  child
}

// Returns list of content values, where each element is
//   a line from the algo body
//
// Parameters:
//   body: Algorithm content.
//   keywords: List of terms.
//   keyword-styles: Method to style keywords.
#let _get-algo-lines(body, keywords, keyword-styles) = {
  if not body.has("children") {
    return ()
  }

  // compute a regex expr for all keywords alltogether
  let kw-regex = _compute-keyword-regex(keywords)
  // creates a nested content block, as show rules nor regex cannot be joined
  // i.e. [#show .. #[#show .. #[#show .... #[#show child]]]]
  let content-replacer(child) = kw-regex.at(1).fold(
    _single-content-replacer(kw-regex.at(0), keyword-styles, child),
    (total, kw) => _single-content-replacer(kw, keyword-styles, total)
  )

  // concatenate consecutive non-whitespace elements
  // i.e. just combine everything that definitely aren't on separate lines
  let text-and-whitespaces = {
    let joined-children = ()
    let temp = none

    for child in body.children {
      if child == [ ] or child == linebreak() or child == parbreak() {
        if temp != none {
          joined-children.push(temp)
          temp = none
        }

        joined-children.push(child)
      } else if child.func() == text {
        temp += content-replacer(child)
      } else {
        temp += child
      }
    }

    if temp != none {
      joined-children.push(temp)
    }

    joined-children
  }

  // filter out non-meaningful whitespace elements
  let text-and-breaks = text-and-whitespaces.filter(
    elem => elem != [ ] and elem != parbreak()
  )

  // handling meaningful whitespace
  // make final list of empty and non-empty lines
  let lines = {
    let joined-lines = ()
    let line-parts = none
    let num-linebreaks = 0

    for elem in text-and-breaks {
      if elem == linebreak() {
        if line-parts != none {
          joined-lines.push(line-parts)
          line-parts = none
        }

        num-linebreaks += 1

        if num-linebreaks > 1 {
          joined-lines.push(none)
        }
      } else {
        line-parts += [#elem ]
        num-linebreaks = 0
      }
    }

    if line-parts != none {
      joined-lines.push(line-parts)
    }

    joined-lines
  }

  return lines
}


// Returns list of algorithm lines with strongly emphasized keywords,
//   correct indentation, and indent guides.
//
// Parameters:
//   lines: List of algorithm lines from _get-algo-lines().
//   indent-size: Size of line indentations.
//   indent-guides: Stroke for indent guides.
//   indent-guides-offset: Horizontal offset of indent guides.
//   inset: Inner padding.
//   row-gutter: Space between lines.
//   main-text-styles: Styling function to apply to the main algorithm text.
//   comment-styles: Styling function to apply to comments.
//   line-number-styles: Styling function to apply to line numbers.
#let _build-formatted-algo-lines(
  lines,
  indent-size,
  indent-guides,
  indent-guides-offset,
  inset,
  row-gutter,
  main-text-styles,
  comment-styles,
  line-number-styles
) = lines.enumerate().map(((i, line)) => {
  _algo-indent-level.display(indent-level => {
    if indent-guides != none {
      _algo-indent-guides(
        indent-guides,
        indent-guides-offset,
        line,
        i,
        lines.len(),
        indent-level,
        indent-size,
        inset,
        row-gutter,
        main-text-styles,
        comment-styles,
        line-number-styles
      )
    }

    box(
      inset: (left: indent-size * indent-level),
      line
    )
  })

  counter(_algo-line-ckey).step()
})


// Layouts algo content in a table.
//
// Parameters:
//   formatted-lines: List of formatted algorithm lines.
//   line-numbers: Whether to have line numbers.
//   comment-prefix: Content to prepend comments with.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers, text, and comments.
//   main-text-styles: Styling function to apply to the main algorithm text.
//   comment-styles: Styling function to apply to comments.
//   line-number-styles: Styling function to apply to line numbers.
#let _build-algo-table(
  formatted-lines,
  line-numbers,
  comment-prefix,
  row-gutter,
  column-gutter,
  main-text-styles,
  comment-styles,
  line-number-styles,
) = { locate(loc => {
  let id-str = str(counter(_algo-id-ckey).at(loc).at(0))
  let comment-dicts = _algo-comment-dicts.final(loc)
  let has-comments = id-str in comment-dicts

  let comment-contents = if has-comments {
    let comments = comment-dicts.at(id-str)

    range(formatted-lines.len()).map(i => {
      let index-str = str(i)

      if index-str in comments {
        comments.at(index-str)
      } else {
        none
      }
    })
  } else {
    none
  }

  let num-columns = 1 + int(line-numbers) + int(has-comments)

  let align-func = {
    let alignments = ()

    if line-numbers {
      alignments.push(right + horizon)
    }

    alignments.push(left + bottom)

    if has-comments {
      alignments.push(left + bottom)
    }

    (x, _) => alignments.at(x)
  }

  // first condition, then compute only neccesary data directly
  let table-data = if line-numbers and has-comments {
    formatted-lines.enumerate(start: 1).map(
      ((i, line)) => (line-number-styles(i), main-text-styles(line))
    ).zip(comment-contents.map(
      cc => if cc == none { none } else {
        comment-styles(comment-prefix + cc)
      })
    ).flatten()
  } else if line-numbers {
    formatted-lines.enumerate(start: 1).map(
      ((i, line)) => (line-number-styles(i), main-text-styles(line))
    ).flatten()
  } else if has-comments {
    formatted-lines.map(main-text-styles).zip(comment-contents.map(
      cc => if cc == none { none } else {
        comment-styles(comment-prefix + cc)
      })
    ).flatten()
  } else {
    formatted-lines.map(main-text-styles)
  }

  table(
    columns: num-columns,
    row-gutter: row-gutter,
    column-gutter: column-gutter,
    align: align-func,
    stroke: none,
    inset: 0pt,
    ..table-data
  )
})}


// Asserts that the current context is an algo element.
// Returns the provided message if the assertion fails.
#let _assert-in-algo(message) = {
  _algo-in-algo-context.display(is-in-algo => {
    _algo-assert(is-in-algo, message: message)
  })
}


// Increases indent in an algo element.
// All uses of #i within a line will be
//   applied to the next line.
#let i = {
  _assert-in-algo("cannot use #i outside an algo element")
  _algo-indent-level.update(n => n + 1)
}


// Decreases indent in an algo element.
// All uses of #d within a line will be
//   applied to the next line.
#let d = {
  _assert-in-algo("cannot use #d outside an algo element")

  _algo-indent-level.display(n => {
    _algo-assert(n - 1 >= 0, message: "dedented too much")
  })

  _algo-indent-level.update(n => n - 1)
}

// Prevents internal from being recognised and displayed as a keyword. Alternatively, one can wrap it also in `#[]`.
//
// Parameters:
//   body: Content.
#let no-keyword(body) = {
  _assert-in-algo("cannot use #no-keyword outside an algo element")
  body
}

// Adds a comment to a line in an algo body.
//
// Parameters:
//   body: Comment content.
//   inline: Whether the comment should be displayed in place.
#let comment(
  body,
  inline: false,
) = {
  _assert-in-algo("cannot use #comment outside an algo element")

  if inline {
    _algo-comment-prefix.display(comment-prefix => {
      _algo-comment-styles.display(comment-styles => comment-styles(
        comment-prefix + body
      ))
    })
  } else {
    locate(loc => {
      let id-str = str(counter(_algo-id-ckey).at(loc).at(0))
      let line-index-str = str(counter(_algo-line-ckey).at(loc).at(0))

      _algo-comment-dicts.update(comment-dicts => {
        let comments = comment-dicts.at(id-str, default: (:))
        let ongoing-comment = comments.at(line-index-str, default: [])
        let comment-content = ongoing-comment + body
        comments.insert(line-index-str, comment-content)
        comment-dicts.insert(id-str, comments)
        comment-dicts
      })
    })
  }
}

// Returns identity function aka no behaviour if x is none and returns x otherwise
#let _none_to_nobehaviour(x) = if x == none { x => x } else { x }

// Displays an algorithm in a block element.
//
// Parameters:
//   body: Algorithm content.
//   header: Algorithm header. Overrides title and parameters.
//   title: Algorithm title. Ignored if header is not none.
//   Parameters: Array of parameters. Ignored if header is not none.
//   line-numbers: Whether to have line numbers.
//   keyword-styles: Styling function to apply on keywords. Use none to not emphasize keywords.
//   keywords: List of terms.
//   comment-prefix: Content to prepend comments with.
//   indent-size: Size of line indentations.
//   indent-guides: Stroke for indent guides.
//   indent-guides-offset: Horizontal offset of indent guides.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding.
//   fill: Fill color.
//   stroke: Border stroke.
//   radius: Corner radius.
//   breakable: Whether the element should be breakable across pages.
//     Warning: indent guides may look off when broken across pages.
//   block-align: Alignment of block. Use none for no alignment.
//   main-text-styles: Styling function to apply to the main algorithm text.
//   comment-styles: Styling function to apply to comments.
//   line-number-styles: Styling function to apply to line numbers.
#let algo(
  body,
  header: none,
  title: none,
  parameters: (),
  line-numbers: true,
  keyword-styles: strong,
  keywords: _algo-default-keywords,
  comment-prefix: "// ",
  indent-size: 20pt,
  indent-guides: none,
  indent-guides-offset: 0pt,
  row-gutter: 10pt,
  column-gutter: 10pt,
  inset: 10pt,
  fill: rgb(98%, 98%, 98%),
  stroke: 1pt + rgb(50%, 50%, 50%),
  radius: 0pt,
  breakable: false,
  block-align: center,
  main-text-styles: x => x,
  comment-styles: x => text(fill: rgb(45%, 45%, 45%))[#x],
  line-number-styles: i => [#i],
) = {
  // change nones to no behaviour
  let keyword-styles     = _none_to_nobehaviour(keyword-styles)
  let main-text-styles   = _none_to_nobehaviour(main-text-styles)
  let comment-styles     = _none_to_nobehaviour(comment-styles)
  let line-number-styles = _none_to_nobehaviour(line-number-styles)

  counter(_algo-id-ckey).step()
  counter(_algo-line-ckey).update(0)
  _algo-comment-prefix.update(comment-prefix)
  // to update the state, we have to pass a function returning a function
  // for typst to understand it not as a function argument
  // we hence use a constant function returning our style function
  _algo-comment-styles.update(fn => comment-styles)
  _algo-indent-level.update(0)
  _algo-in-algo-context.update(true)

  let algo-header = _build-algo-header(header, title, parameters)

  let lines = _get-algo-lines(
    body,
    keywords,
    keyword-styles
  )
  let formatted-lines = _build-formatted-algo-lines(
    lines,
    indent-size,
    indent-guides,
    indent-guides-offset,
    inset,
    row-gutter,
    main-text-styles,
    comment-styles,
    line-number-styles,
  )

  let algo-table = _build-algo-table(
    formatted-lines,
    line-numbers,
    comment-prefix,
    row-gutter,
    column-gutter,
    main-text-styles,
    comment-styles,
    line-number-styles,
  )

  let algo-block = block(
    width: auto,
    height: auto,
    fill: fill,
    stroke: stroke,
    radius: radius,
    inset: inset,
    outset: 0pt,
    breakable: breakable,
    {
      set align(start + top)
      algo-header
      v(weak: true, row-gutter)
      align(left, algo-table)
    }
  )

  // display content
  set par(justify: false)

  if block-align != none {
    align(block-align, algo-block)
  } else {
    algo-block
  }

  _algo-in-algo-context.update(false)
}


// Returns tuple of lengths:
//   - height of text (baseline to cap-height)
//   - height of ascenders
//   - height of descenders
//
// Parameters:
//   main-text-styles: Styling function to apply to the main algorithm text.
//   styles: styles value obtained from call to style
#let _get-code-text-height(
  main-text-styles,
  styles
) = {
  let styled-ascii = main-text-styles(raw(_ascii))

  let text-height = measure({
    show raw: set text(top-edge: "cap-height", bottom-edge: "baseline")
    styled-ascii
  }, styles).height

  let text-and-ascender-height = measure({
    show raw: set text(top-edge: "ascender", bottom-edge: "baseline")
    styled-ascii
  }, styles).height

  let text-and-descender-height = measure({
    show raw: set text(top-edge: "cap-height", bottom-edge: "descender")
    styled-ascii
  }, styles).height

  return (
    text-height,
    text-and-ascender-height - text-height,
    text-and-descender-height - text-height,
  )
}


// Determines tab size being used by the given text.
// Searches for the first line that starts with whitespace and
//   returns the number of spaces the line starts with. If no
//   such line is found, -1 is returned.
//
// Parameters:
//   line-strs: Array of strings, where each string is a line from the
//     provided raw text.
#let _get-code-tab-size(line-strs) = {
  for line in line-strs {
    let starting-whitespace = line.replace(regex("\t"), "").find(regex("^ +"))

    if starting-whitespace != none {
      return starting-whitespace.len()
    }
  }

  return -1
}


// Determines the indent level at each line of the given text.
// Returns a list of integers, where the ith integer is the indent
//   level of the ith line.
//
// Parameters:
//   line-strs: Array of strings, where each string is a line from the
//     provided raw text.
//   tab-size: tab-size used by the given code
#let _get-code-indent-levels(line-strs, tab-size) = {
  line-strs.map(line => {
    let starting-whitespace = line.replace(regex("\t"), "").find(regex("^ +"))

    if starting-whitespace == none {
      0
    } else {
      calc.floor(starting-whitespace.len() / tab-size)
    }
  })
}


// Returns list of tuples, where the ith tuple contains:
//   - a list of boxed clips of each line-wrapped component of the ith line
//   - an integer indicating the indent level of the ith line
//
// Parameters:
//   raw-text: Raw text block.
//   line-numbers: Whether there are line numbers.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding of containing block.
//   main-text-styles: Styling function to apply to the main algorithm text.
//   line-number-styles: Styling function to apply to line numbers.
//   text-height: Height of raw text, baseline to cap-height.
//   ascender-height: Height of raw text ascenders.
//   descender-height: Height of raw text descenders.
//   indent-levels: List of integers indicating indent levels of each line.
//   container-size: Size of the outer container.
//   styles: Active styles.
#let _get-code-line-data(
  raw-text,
  line-numbers,
  column-gutter,
  inset,
  main-text-styles,
  line-number-styles,
  text-height,
  ascender-height,
  descender-height,
  indent-levels,
  container-size,
  styles
) = {
  let line-spacing = 100pt
  let line-strs = raw-text.text.split("\n")
  let num-lines = line-strs.len()
  let container-width = container-size.width

  let line-number-col-width = calc.max(
    ..range(1, num-lines + 1).map(
      i => line-number-styles(i)
    ).filter(x => x != []).map(
      x => measure(x, styles).width
    )
  )

  let max-text-area-width = (
    container-size.width - inset * 2 - if line-numbers {
      (column-gutter + line-number-col-width)
    } else {
      0pt
    }
  )

  let max-text-width = measure({
    show raw: main-text-styles
    raw-text
  }, styles).width

  let real-text-width = calc.min(max-text-width, max-text-area-width)

  let styled-raw-text = {
    show raw: main-text-styles
    set par(leading: line-spacing)
    block(width: real-text-width, raw-text)
  }

  let line-data = ()
  let line-count = 0

  for (i, line) in line-strs.enumerate() {
    let indent-level = indent-levels.at(i)

    let line-width = measure(
      main-text-styles(raw(line)),
      styles
    ).width

    let line-wrapped-components = ()

    for j in range(calc.max(1, calc.ceil(line-width / real-text-width))) {
      let is-wrapped = j > 0
      let real-indent-level = if is-wrapped { 0 } else { indent-level }

      let line-clip = {
        set align(start + top)

        box(move(
          dy: descender-height * 0.5,
          box(
            width: real-text-width,
            height: text-height + ascender-height + descender-height,
            clip: true,
            move(
              dy: -((text-height+line-spacing) * line-count) + ascender-height,
              styled-raw-text
            )
          )
        ))
      }

      line-wrapped-components.push(line-clip)
      line-count += 1
    }

    line-data.push((line-wrapped-components, indent-level))
  }

  return line-data
}


// Create indent guides for a given line of a code element.
// Given the content of the line, calculates size of the content
//   and creates indent guides of sufficient length.
//
// Parameters:
//   indent-guides: Stroke for drawing indent guides.
//   indent-guides-offset: Horizontal offset of indent guides.
//   content: The main content that appears on the given line.
//   line-index: The 0-based index of the given line.
//   num-lines: The total number of lines in the current element.
//   indent-level: The indent level at the given line.
//   tab-size: Amount of spaces that should be considered an indent.
//   block-inset: The inset of the current element.
//   row-gutter: The row-gutter of the current element.
//   main-text-styles: Styling function to apply to the main algorithm text.
//   line-number-styles: Styling function to apply to line numbers.
#let _code-indent-guides(
  indent-guides,
  indent-guides-offset,
  content,
  line-index,
  num-lines,
  indent-level,
  tab-size,
  block-inset,
  row-gutter,
  main-text-styles,
  line-number-styles,
) = { style(styles => {
  // heuristically determine the height of the row
  let row-height = calc.max(
    // height of content
    measure(content, styles).height,

    // height of raw text
    measure(
      main-text-styles(raw(_ascii)),
      styles
    ).height,

    // height of line numbers
    measure(
      line-number-styles(line-index),
      styles
    ).height
  )

  let indent-size = measure(
    main-text-styles(raw("a" * tab-size)),
    styles
  ).width

  // TODO: WHY?!
    // converting input parameters to absolute lengths
    // let block-inset-abs = measure(rect(width: block-inset), styles).width
    // let row-gutter-abs = measure(rect(width: row-gutter), styles).width

  // display indent guides at the current line
  _indent-guides(
    indent-guides,
    indent-guides-offset,
    indent-level,
    indent-size,
    row-height,
    block-inset,//-abs,
    row-gutter,//-abs,
    line-index == 0,            // is first line?
    line-index == num-lines - 1 // is last line?
  )
})}


// Layouts code content in a table.
//
// Parameters:
//   line-data: Data received from _get-code-line-data().
//   indent-levels: List of indent levels from _get-code-indent-levels().
//   line-numbers: Whether to have line numbers.
//   indent-guides: Stroke for indent guides.
//   indent-guides-offset: Horizontal offset of indent guides.
//   tab-size: Amount of spaces that should be considered an indent.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding.
//   main-text-styles: Styling function to apply to the main algorithm text.
//   line-number-styles: Styling function to apply to line numbers.
#let _build-code-table(
  line-data,
  indent-levels,
  line-numbers,
  indent-guides,
  indent-guides-offset,
  tab-size,
  row-gutter,
  column-gutter,
  inset,
  main-text-styles,
  line-number-styles,
) = {
  let flattened-line-data = line-data.map(e => {
    let line-wrapped-components = e.at(0)
    let indent-level = e.at(1)

    line-wrapped-components.enumerate().map(((i, line-clip)) => {
      let is-wrapped = i > 0
      let real-indent-level = if is-wrapped { 0 } else { indent-level }
      (line-clip, is-wrapped, real-indent-level)
    })
  }).sum() // sum works as a one level flatten operation

  let table-data = if line-numbers {
    flattened-line-data.enumerate().map(((i, info)) => {
      let line-clip = info.at(0)
      let is-wrapped = info.at(1)
      let indent-level = info.at(2)

      (
        if is-wrapped {
          none
        } else {
          line-number-styles(i + 1)
        }, {
          if indent-guides != none { // could also be moved out
            _code-indent-guides(
              indent-guides,
              indent-guides-offset,
              line-clip,
              i,
              flattened-line-data.len(),
              indent-level,
              tab-size,
              inset,
              row-gutter,
              main-text-styles,
              line-number-styles
            )
          }

          box(line-clip)
        }
      )
    }).flatten()
  } else {
    flattened-line-data.enumerate().map(((i, info)) => {
      let line-clip = info.at(0)
      let is-wrapped = info.at(1)
      let indent-level = info.at(2)

      if indent-guides != none {
        _code-indent-guides(
          indent-guides,
          indent-guides-offset,
          line-clip,
          i,
          flattened-line-data.len(),
          indent-level,
          tab-size,
          inset,
          row-gutter,
          main-text-styles,
          line-number-styles
        )
      }

      box(line-clip)
    })
  }

  table(
    columns: if line-numbers {2} else {1},
    inset: 0pt,
    stroke: none,
    fill: none,
    row-gutter: row-gutter,
    column-gutter: column-gutter,
    align: if line-numbers {
      (x, _) => (right+horizon, left+bottom).at(x)
    } else {
      left
    },
    ..table-data
  )
}


// Displays code in a block element.
//
// Parameters:
//   body: Raw text.
//   line-numbers: Whether to have line numbers.
//   indent-guides: Stroke for indent guides.
//   indent-guides-offset: Horizontal offset of indent guides.
//   tab-size: Amount of spaces that should be considered an indent.
//     Determined automatically if unspecified.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding.
//   fill: Fill color.
//   stroke: Border stroke.
//   radius: Corner radius.
//   breakable: Whether the element should be breakable across pages.
//     Warning: indent guides may look off when broken across pages.
//   block-align: Alignment of block. Use none for no alignment.
//   main-text-styles: Styling function to apply to the main algorithm text.
//   line-number-styles: Styling function to apply to line numbers.
#let code(
  body,
  line-numbers: true,
  indent-guides: none,
  indent-guides-offset: 0pt,
  tab-size: auto,
  row-gutter: 10pt,
  column-gutter: 10pt,
  inset: 10pt,
  fill: rgb(98%, 98%, 98%),
  stroke: 1pt + rgb(50%, 50%, 50%),
  radius: 0pt,
  breakable: false,
  block-align: center,
  main-text-styles: x => x,
  line-number-styles: i => [#i],
) = {
  // change nones to no behaviour
  let main-text-styles = _none_to_nobehaviour(main-text-styles)
  let line-number-styles = _none_to_nobehaviour(line-number-styles)
  
  layout(size => style(styles => {
  let raw-text = if body.func() == raw {
    body
  } else if body != [] and body.has("children") {
    let raw-children = body.children.filter(e => e.func() == raw)

    _algo-assert(
      raw-children.len() > 0,
      message: "must provide raw text to code"
    )

    _algo-assert(
      raw-children.len() == 1,
      message: "cannot pass multiple raw text blocks to code"
    )

    raw-children.first()
  } else {
    return
  }

  if raw-text.text == "" {
    return
  }

  let line-strs = raw-text.text.split("\n")

  let (text-height, asc-height, desc-height) = _get-code-text-height(
    main-text-styles,
    styles
  )

  let real-row-gutter = calc.max(0pt, row-gutter - asc-height - desc-height)

  let real-tab-size = if tab-size == auto {
    _get-code-tab-size(line-strs)
  } else {
    tab-size
  }

  // no indents exist, so ignore indent-guides
  let (real-indent-guides, indent-levels) = if real-tab-size == -1 {
    (none, (0,) * line-strs.len())
  } else {
    (indent-guides, _get-code-indent-levels(line-strs, real-tab-size))
  }

  let line-data = _get-code-line-data(
    raw-text,
    line-numbers,
    column-gutter,
    inset,
    main-text-styles,
    line-number-styles,
    text-height,
    asc-height + 1pt,
    desc-height + 1pt,
    indent-levels,
    size,
    styles,
  )

  let code-table = _build-code-table(
    line-data,
    indent-levels,
    line-numbers,
    real-indent-guides,
    indent-guides-offset,
    real-tab-size,
    real-row-gutter,
    column-gutter,
    inset,
    main-text-styles,
    line-number-styles,
  )

  // build block
  let code-block = block(
    width: auto,
    fill: fill,
    stroke: stroke,
    radius: radius,
    inset: inset,
    breakable: breakable
  )[
    #set align(start + top)
    #code-table
  ]

  // display content
  set par(justify: false)

  if block-align != none {
    align(block-align, code-block)
  } else {
    code-block
  }
}))}
