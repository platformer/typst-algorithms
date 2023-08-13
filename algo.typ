#import "@preview/tablex:0.0.5": gridx, colspanx, vlinex

// State value to track whether the current context is an algo element.
// If not, #i, #d, #comment, #no-emph commands should fail.
#let _algo-in-algo-context = state("_algo-in-algo-context", false)

// State value to track whether the current context is display mode.
// If not, #i, #d, #comment commands will update relevant state;
//   otherwise they do nothing.
#let _algo-in-display-context = state("_algo-in-display-context", false)

// state value for storing current comment-prefix passed to algo
#let _algo-comment-prefix = state("_algo-comment-prefix", [])

// state value for storing current comment-styles passed to algo
#let _algo-comment-styles = state("_algo-comment-styles", (:))

// State value to track the indent level of each line of an algo element.
// Is a list where the ith element is an integer indicating the indent
//   level of the (i+1)th line, since the first line cannot be indented.
#let _algo-indent-levels = state("_algo-indent-levels", ())

// State value to track the comments on each line of an algo element.
// Is a list where the ith element is the content of the comment on
//   the ith line.
#let _algo-comments = state("_algo-comments", ())

// list of default keywords that will be highlighted by strong-keywords
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
}).fold((), (acc, e) => acc + e)

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


// Asserts that the current context is an algo element.
// Returns the provided message if the assertion fails.
//
// Parameters:
//   message: Message to return if asssertion fails.
#let _assert-in-algo(message) = {
  _algo-in-algo-context.display(is-in-algo => {
    _algo-assert(is-in-algo, message: message)
  })
}


// Layouts algo body in a hidden area off the page so that all internal
//   commands are ran and all state values are primed for final display.
//
// Parameters:
//   body: Algorithm content.
#let _prepare-algo-state(body) = {
  place(dx: -100%, hide({
    show linebreak: {
      _algo-indent-levels.update(indent-levels => {
        indent-levels.push(indent-levels.last())
        indent-levels
      })

      _algo-comments.update(comments => {
        comments.push([])
        comments
      })
    }

    _algo-indent-levels.update((0,))
    _algo-comments.update(([],))
    _algo-in-display-context.update(false)
    body
    _algo-in-display-context.update(true)
  }))
}


// Returns list of content values, where each element is
//   a line from the algo body.
//
// Parameters:
//   body: Algorithm content.
#let _get-algo-lines(body) = {
  if not body.has("children") {
    return ()
  }

  // concatenate consecutive non-whitespace elements
  // i.e. just combine everything that definitely
  //      aren't on separate lines
  let text-and-whitespaces = {
    let joined-children = ()
    let temp = []

    for child in body.children {
      if (
        child == [ ]
        or child == linebreak()
        or child == parbreak()
      ){
        if temp != [] {
          joined-children.push(temp)
          temp = []
        }

        joined-children.push(child)
      } else {
        temp += child
      }
    }

    if temp != [] {
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
    let line-parts = []
    let num-linebreaks = 0

    for elem in text-and-breaks {
      if elem == linebreak() {
        if line-parts != [] {
          joined-lines.push(line-parts)
          line-parts = []
        }

        num-linebreaks += 1

        if num-linebreaks > 1 {
          joined-lines.push([])
        }
      } else {
        line-parts += [#elem ]
        num-linebreaks = 0
      }
    }

    if line-parts != [] {
      joined-lines.push(line-parts)
    }

    joined-lines
  }

  return lines
}


// Returns list of algorithm lines with strongly emphasized keywords.
//
// Parameters:
//   lines: List of algorithm lines from _get-algo-lines().
//   keywords: List of keywords to receive strong emphasis.
#let _strongly-emphasize-keywords(lines, keywords) = {
  // convert keywords to content values
  let content-keywords = keywords.map(e => {
    if type(e) == "string" {
      [#e]
    } else {
      e
    }
  })

  lines.map(line => {
    show regex("\S+"): it => {
      if it in content-keywords {
        strong(it)
      } else {
        it
      }
    }

    line
  })
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

      if type(title) == "string" {
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

      for (i, param) in parameters.enumerate() {
        if type(param) == "string" {
          math.italic(param)
        } else {
          param
        }

        if i < parameters.len() - 1 {
          [, ]
        }
      }

      $)$
    }

    if title != none or parameters != () {
      [:]
    }
  }
}


// Layouts algo content in a table.
//
// Parameters:
//   lines: List of algorithm lines from _get-algo-lines().
//   line-numbers: Whether to have line numbers.
//   comment-prefix: Content to prepend comments with.
//   indent-size: Size of line indentations.
//   indent-guides: Stroke for indent guides.
//   indent-guides-offset: Horizontal offset of indent guides.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers, text, and comments.
//   main-text-styles: Dictionary of styling options for the algorithm steps.
//   comment-styles: Dictionary of styling options for comment text.
//   line-number-styles: Dictionary of styling options for the line numbers.
#let _build-algo-table(
  lines,
  line-numbers,
  comment-prefix,
  indent-size,
  indent-guides,
  indent-guides-offset,
  row-gutter,
  column-gutter,
  main-text-styles,
  comment-styles,
  line-number-styles,
) = { _algo-indent-levels.display(indent-levels => {
      _algo-comments.display(comments => {
  _algo-assert(
    indent-guides-offset >= 0pt,
    message: "indent-guides-offset cannot be negative"
  )

  _algo-assert(
    indent-guides-offset < indent-size,
    message: "indent-guides-offset must be less than indent-size"
  )

  let has-indent-guides = indent-guides != none
  let has-comments = comments.any(e => e != [])
  let max-indent = calc.max(..indent-levels)

  let num-columns = (
    1 +
    max-indent +
    int(has-indent-guides) * max-indent +
    int(line-numbers) * 2 +
    int(has-comments) * 2
  )

  let align-func = {
    let alignments = ()

    if line-numbers {
      alignments.push(right)
      alignments += (left,) * (num-columns - 1)
    } else {
      alignments += (left,) * num-columns
    }

    (x, _) => alignments.at(x) + horizon
  }

  let (pre-indent-guide-space, post-indent-guide-space) = {
    if has-indent-guides {
      let pre-spacing = (
        indent-guides-offset +
        indent-guides.thickness / 2 +
        0.5pt
      )

      (pre-spacing, indent-size - pre-spacing)
    } else {
      (none, indent-size)
    }
  }

  let table-data = ()

  for (i, line) in lines.enumerate() {
    let indent-level = if i == 0 {0} else {indent-levels.at(i - 1)}
    let line-number = i + 1

    let text-col-span = (
      1 + (max-indent - indent-level) * (int(has-indent-guides) + 1)
    )

    if line-numbers {
      table-data.push({
        set text(..line-number-styles)
        str(line-number)
      })

      table-data.push(h(column-gutter))
    }

    for j in range(indent-level) {
      if has-indent-guides {
        table-data += (
          h(pre-indent-guide-space),
          vlinex(
            start: i,
            end: i+1,
            stop-pre-gutter: true,
            expand: row-gutter / 2,
            stroke: indent-guides,
          )
        )
      }

      table-data.push(h(post-indent-guide-space))
    }

    table-data.push(colspanx(text-col-span)[
      #set text(..main-text-styles)
      #line
    ])

    if has-comments {
      table-data.push(h(column-gutter))

      table-data.push({
        set text(..comment-styles)

        if comments.at(i) != [] {
          comment-prefix
        }

        comments.at(i)
      })
    }
  }

  gridx(
    columns: num-columns,
    column-gutter: 0pt,
    row-gutter: row-gutter,
    align: align-func,
    stroke: none,
    inset: 0pt,
    ..table-data
  )
})})}


// Increases indent in an algo element.
// All uses of #i within a line will be
//   applied to the next line.
#let i = {
  _assert-in-algo("cannot use #i outside an algo element")

  _algo-in-display-context.display(in-display-context => {
    if not in-display-context {
      _algo-indent-levels.update(indent-levels => {
        indent-levels.last() += 1
        indent-levels
      })
    }
  })
}


// Decreases indent in an algo element.
// All uses of #d within a line will be
//   applied to the next line.
#let d = {
  _assert-in-algo("cannot use #d outside an algo element")

  _algo-in-display-context.display(in-display-context => {
    if not in-display-context {
      _algo-indent-levels.update(indent-levels => {
        let new-indent-level = indent-levels.last() - 1
        _algo-assert(new-indent-level >= 0, message: "dedented too much")
        indent-levels.last() = new-indent-level
        indent-levels
      })
    }
  })
}


// Prevents internal content from being strongly emphasized.
//
// Parameters:
//   body: Content.
#let no-emph(body) = {
  _assert-in-algo("cannot use #no-emph outside an algo element")
  set strong(delta: 0)
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
      _algo-comment-styles.display(comment-styles => {
        set text(..comment-styles)
        comment-prefix
        no-emph(body)
      })
    })
  } else {
    _algo-in-display-context.display(in-display-context => {
      if not in-display-context {
        _algo-comments.update(comments => {
          comments.last() += body
          comments
        })
      }
    })
  }
}


// Displays an algorithm in a block element.
//
// Parameters:
//   body: Algorithm content.
//   header: Algorithm header. Overrides title and parameters.
//   title: Algorithm title. Ignored if header is not none.
//   Parameters: Array of parameters. Ignored if header is not none.
//   line-numbers: Whether to have line numbers.
//   strong-keywords: Whether to have bold keywords.
//   keywords: List of terms to receive strong emphasis if
//     strong-keywords is true.
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
//   main-text-styles: Dictionary of styling options for the algorithm steps.
//     Supports any parameter in Typst's native text function.
//   comment-styles: Dictionary of styling options for comment text.
//     Supports any parameter in Typst's native text function.
//   line-number-styles: Dictionary of styling options for the line numbers.
//     Supports any parameter in Typst's native text function.
#let algo(
  body,
  header: none,
  title: none,
  parameters: (),
  line-numbers: true,
  strong-keywords: true,
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
  main-text-styles: (:),
  comment-styles: (fill: rgb(45%, 45%, 45%)),
  line-number-styles: (:),
) = {
  _algo-in-algo-context.update(true)
  _algo-comment-prefix.update(comment-prefix)
  _algo-comment-styles.update(comment-styles)
  _prepare-algo-state(body)
  let lines = _get-algo-lines(body)

  let formatted-lines = if strong-keywords {
    _strongly-emphasize-keywords(lines, keywords)
  } else {
    lines
  }

  let algo-header = _build-algo-header(header, title, parameters)

  let algo-table = _build-algo-table(
    formatted-lines,
    line-numbers,
    comment-prefix,
    indent-size,
    indent-guides,
    indent-guides-offset,
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
    breakable: breakable
  )[
    #set align(start + top)
    #algo-header
    #v(weak: true, row-gutter)
    #align(left, algo-table)
  ]

  // display content
  set par(justify: false)

  if block-align != none {
    align(block-align, algo-block)
  } else {
    algo-block
  }

  _algo-in-algo-context.update(false)
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
    let starting-whitespace = line.replace(regex("\t"), "")
                                  .find(regex("^ +"))

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
//   tab-size: Tab-size used by the given code.
#let _get-code-indent-levels(line-strs, tab-size) = {
  line-strs.map(line => {
    let starting-whitespace = line.replace(regex("\t"), "")
                                  .find(regex("^ +"))

    if starting-whitespace == none {
      0
    } else {
      calc.floor(starting-whitespace.len() / tab-size)
    }
  })
}


// Returns tuple of lengths:
//   - height of text (baseline to cap-height)
//   - height of ascenders
//   - height of descenders
//
// Parameters:
//   main-text-styles: Dictionary of styling options for the source code.
//   styles: styles value obtained from call to style
#let _get-code-text-height(
  main-text-styles,
  styles
) = {
  let styled-ascii = {
    show raw: set text(..main-text-styles)
    raw(_ascii)
  }

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


// Returns list of tuples, where the ith tuple contains the following:
//   - a list of boxed clips of each line-wrapped component of the ith line
//   - an integer indicating the indent level of the ith line
//
// Parameters:
//   raw-text: Raw text block.
//   line-strs: Array of strings, where each string is a line from the
//     provided raw text.
//   line-numbers: Whether there are line numbers.
//   indent-size: Width of an indent.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding of containing block.
//   main-text-styles: Dictionary of styling options for the source code.
//   line-number-styles: Dictionary of styling options for the line numbers.
//   text-height: Height of raw text, baseline to cap-height.
//   ascender-height: Length of raw text ascenders.
//   descender-height: Length of raw text descenders.
//   indent-levels: List of integers indicating indent levels of each line.
//   container-size: Size of the outer container.
//   styles: Active styles.
#let _get-code-line-data(
  raw-text,
  line-strs,
  line-numbers,
  indent-size,
  column-gutter,
  inset,
  main-text-styles,
  line-number-styles,
  text-height,
  ascender-height,
  descender-height,
  indent-levels,
  container-size,
  styles,
) = {
  let line-spacing = 100pt
  let num-lines = line-strs.len()
  let container-width = container-size.width

  let line-number-col-width = measure({
    set text(..line-number-styles)
    "0" * (calc.floor(calc.log(num-lines)) + 1)
  }, styles).width

  let max-text-area-width = (
    container-size.width - inset * 2 - if line-numbers {
      (column-gutter + line-number-col-width)
    } else {
      0pt
    }
  )

  let max-text-width = measure({
    show raw: set text(..main-text-styles)
    raw-text
  }, styles).width

  let real-text-width = calc.min(max-text-width, max-text-area-width)

  let styled-raw-text = {
    show raw: set text(..main-text-styles)
    set par(leading: line-spacing)
    block(width: real-text-width, raw-text)
  }

  let line-data = ()
  let line-count = 0

  for i in range(num-lines) {
    let indent-level = indent-levels.at(i)

    let line-width = measure({
      show raw: set text(..main-text-styles)
      raw(line-strs.at(i))
    }, styles).width

    let line-wrapped-components = ()

    for j in range(calc.max(1, calc.ceil(line-width / real-text-width))) {
      let is-wrapped = j > 0
      let real-indent-level = if is-wrapped {0} else {indent-level}

      let line-clip = {
        set align(start + top)

        box(move(
          dy: descender-height * 0.5,
          box(
            width: real-text-width - indent-size * real-indent-level,
            height: text-height + ascender-height + descender-height,
            clip: true,
            move(
              dx: -(indent-size * real-indent-level),
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


// Layouts code content in a table.
//
// Parameters:
//   line-data: Data received from _get-code-line-data().
//   line-numbers: Whether to have line numbers.
//   indent-size: Width of an indent.
//   indent-guides: Stroke for indent guides.
//   indent-guides-offset: Horizontal offset of indent guides.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers and text.
//   line-number-styles: Dictionary of styling options for the line numbers.
#let _build-code-table(
  line-data,
  line-numbers,
  indent-size,
  indent-guides,
  indent-guides-offset,
  row-gutter,
  column-gutter,
  line-number-styles,
) = {
  let flattened-line-data = line-data.fold((), (acc, e) => {
    let line-wrapped-components = e.at(0)
    let indent-level = e.at(1)

    for (i, line-clip) in line-wrapped-components.enumerate() {
      let is-wrapped = i > 0
      let real-indent-level = if is-wrapped {0} else {indent-level}
      acc.push((line-clip, is-wrapped, real-indent-level))
    }

    acc
  })

  let has-indent-guides = indent-guides != none
  let max-indent = calc.max(..flattened-line-data.map(e => e.at(2)))

  let num-columns = (
    1 +
    max-indent +
    int(has-indent-guides) * max-indent +
    int(line-numbers) * 2
  )

  let align-func = {
    let alignments = ()

    if line-numbers {
      alignments.push(right)
      alignments += (left,) * (num-columns - 1)
    } else {
      alignments += (left,) * num-columns
    }

    (x, _) => alignments.at(x) + horizon
  }

  let (pre-indent-guide-space, post-indent-guide-space) = {
    if has-indent-guides {
      let pre-spacing = (
        indent-guides-offset +
        indent-guides.thickness / 2 +
        0.5pt
      )

      (pre-spacing, indent-size - pre-spacing)
    } else {
      (none, indent-size)
    }
  }

  let table-data = ()

  for (i, info) in flattened-line-data.enumerate() {
    let line-clip = info.at(0)
    let is-wrapped = info.at(1)
    let indent-level = info.at(2)

    let text-col-span = (
      1 + (max-indent - indent-level) * (int(has-indent-guides) + 1)
    )

    if line-numbers {
      if is-wrapped {
        table-data.push([])
      } else {
        table-data.push({
          set text(..line-number-styles)
          str(i + 1)
        })
      }

      table-data.push(h(column-gutter))
    }

    for j in range(indent-level) {
      if has-indent-guides {
        table-data += (
          h(pre-indent-guide-space),
          vlinex(
            start: i,
            end: i+1,
            stop-pre-gutter: true,
            expand: row-gutter / 2,
            stroke: indent-guides,
          )
        )
      }

      table-data.push(h(post-indent-guide-space))
    }

    table-data.push(colspanx(text-col-span, line-clip))
  }

  gridx(
    columns: num-columns,
    column-gutter: 0pt,
    row-gutter: row-gutter,
    align: align-func,
    stroke: none,
    inset: 0pt,
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
//   main-text-styles: Dictionary of styling options for the source code.
//     Supports any parameter in Typst's native text function.
//   line-number-styles: Dictionary of styling options for the line numbers.
//     Supports any parameter in Typst's native text function.
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
  main-text-styles: (:),
  line-number-styles: (:),
) = { layout(container-size => style(styles => {
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

  let effective-tab-size = if tab-size == auto {
    _get-code-tab-size(line-strs)
  } else {
    tab-size
  }

  let (indent-size, indent-levels) = if effective-tab-size == -1 {
    (
      0pt,
      (0,) * line-strs.len()
    )
  } else {
    (
      measure({
        set text(..main-text-styles)
        raw("a" * effective-tab-size)
      }, styles).width,
      _get-code-indent-levels(line-strs, effective-tab-size)
    )
  }

  let (text-height, asc-height, desc-height) = _get-code-text-height(
    main-text-styles,
    styles
  )

  let real-row-gutter = calc.max(0pt, row-gutter - asc-height - desc-height)

  let line-data = _get-code-line-data(
    raw-text,
    line-strs,
    line-numbers,
    indent-size,
    column-gutter,
    inset,
    main-text-styles,
    line-number-styles,
    text-height,
    asc-height,
    desc-height,
    indent-levels,
    container-size,
    styles,
  )

  let code-table = _build-code-table(
    line-data,
    line-numbers,
    indent-size,
    indent-guides,
    indent-guides-offset,
    real-row-gutter,
    column-gutter,
    line-number-styles,
  )

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
