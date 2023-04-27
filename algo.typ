// key to indent counter
#let _algo-indent-key = "_algo-indent"


// list of default keywords
#let _algo-default-keywords = (
  "if",
  "else",
  "then",
  "while",
  "for",
  "do",
  ":",
  "end",
  "and",
  "or",
  "not",
  "in",
  "to",
  "down",
  "let",
  "return",
  "goto",
)


// Increases indent in an algo element.
// All uses of #i within a line will be
//   applied to the next line.
#let i = { counter(_algo-indent-key).step() }


// Decreases indent in an algo element.
// All uses of #d within a line will be
//   applied to the next line.
#let d = {
  counter(_algo-indent-key).update(n => {
    assert(n - 1 >= 0, message: "dedented too much")
    n - 1
  })
}


// Displays an algorithm in a block element.
//
// Parameters:
//   body: Algorithm text.
//   title: Algorithm title.
//   Parameters: Array of parameters.
//   line-numbers: Whether to have line numbers.
//   strong-keywords: Whether to have bold keywords.
//   keywords: List of terms to receive strong emphasis if
//     strong-keywords is true.
//   indent-size: Size of line indentations.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding.
//   fill: Fill color.
//   stroke: Border stroke.
#let algo(
  body,
  title: none,
  parameters: (),
  line-numbers: true,
  strong-keywords: false,
  keywords: _algo-default-keywords,
  indent-size: 20pt,
  row-gutter: 10pt,
  column-gutter: 10pt,
  inset: 10pt,
  fill: rgb(98%, 98%, 98%),
  stroke: 1pt + rgb(50%, 50%, 50%)
) = {
  set par(justify: false)
  counter(_algo-indent-key).update(0)

  // convert keywords to content values
  keywords = keywords.map(e => {
    if type(e) == "string" {
      [#e]
    } else {
      e
    }
  })

  // sorts body.children such that, between portions of content,
  // indentation changes always occur before whitespace
  // makes placement of indentation commands more flexible in body
  let sorted-children = {
    let whitespaces = ()
    let indent-updates = ()
    let sorted-elems = ()

    for child in body.children {
      if (
        child == [ ]
        or child == linebreak()
        or child == parbreak()
      ) {
        whitespaces.push(child)
        sorted-elems += indent-updates
        indent-updates = ()
      } else if repr(child).starts-with(
        "update(counter: counter(\"" + _algo-indent-key + "\")"
      ) {
        indent-updates.push(child)
      } else {
        sorted-elems += indent-updates
        sorted-elems += whitespaces
        sorted-elems.push(child)
        indent-updates = ()
        whitespaces = ()
      }
    }

    sorted-elems += indent-updates
    sorted-elems += whitespaces
    sorted-elems
  }

  // concatenate consecutive non-whitespace elements
  // i.e. just combine everything that definitely aren't
  // on separate lines
  let text-and-whitespaces = {
    let joined-children = ()
    let temp = []

    for child in sorted-children {
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
    // join consecutive lines not separated by an explicit
    // linebreak with a space
    let joined-lines = ()
    let line-parts = []
    let num-linebreaks = 0

    for (i, line) in text-and-breaks.enumerate() {
      if line == linebreak() {
        if line-parts != [] {
          joined-lines.push(line-parts)
          line-parts = []
        }

        num-linebreaks += 1

        if num-linebreaks > 1 {
          joined-lines.push([])
        }
      } else {
        line-parts += [#line ]
        num-linebreaks = 0
      }
    }

    if line-parts != [] {
      joined-lines.push(line-parts)
    }

    joined-lines
  }

  // build table input (with line numbers if specified)
  let rows = ()

  for (i, line) in lines.enumerate() {
    let formatted-line = {
      // show keywords in bold
      show regex("\S+"): it => {
        if strong-keywords and it in keywords {
          strong(it)
        } else {
          it
        }
      }

      counter(_algo-indent-key).display(n =>
        pad(
          left: indent-size * n,
          line
        )
      )
    }

    if line-numbers {
      let line-number = i + 1
      rows.push([#line-number])
    }

    rows.push(formatted-line)
  }

  // build algorithm header
  let algo-header = {
    set align(left)

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

  align(center, block(
    width: auto,
    height: auto,
    fill: fill,
    stroke: stroke,
    inset: inset,
    outset: 0pt,
    breakable: true
  )[
    #algo-header
    #v(weak: true, row-gutter)

    #align(left, table(
      columns: if line-numbers {2} else {1},
      column-gutter: column-gutter,
      row-gutter: row-gutter,
      align:
        if line-numbers {
          (x, _) => (right, left).at(x)
        } else {
          left
        }
      ,
      stroke: none,
      inset: 0pt,
      ..rows
    ))
  ])
}


// Displays code in a block element.
// Credit to @Vinaigrette#5555 on Discord.
//
// Parameters:
//   body: Raw text.
//   line-numbers. Whether to have line numbers.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding.
//   fill: Fill color.
//   stroke: Border stroke.
#let code(
  body,
  line-numbers: true,
  row-gutter: 10pt,
  column-gutter: 10pt,
  inset: 10pt,
  fill: rgb(98%, 98%, 98%),
  stroke: 1pt + rgb(50%, 50%, 50%)
) = {
  set par(justify: false)
  let content = ()
  let i = 1

  for item in body.children {
    if item.func() == raw {
      for line in item.text.split("\n") {
        if line-numbers {
          content.push(str(i))
        }

        content.push(raw(line, lang: item.lang))
        i += 1
      }
    }
  }

  align(center, block(
    stroke: stroke,
    inset: inset,
    fill: fill,
    width: auto,
    breakable: true
  )[
    #table(
      columns: if line-numbers {2} else {1},
      inset: 0pt,
      stroke: none,
      fill: none,
      row-gutter: row-gutter,
      column-gutter: column-gutter,
      align:
        if line-numbers {
          (x, _) => (right, left).at(x)
        } else {
          left
        }
      ,
      ..content
    )
  ])
}
