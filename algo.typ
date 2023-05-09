// counter to track the number algo elements
#let _algo-counter-key = "_algo-counter"

// counter to track the current indent level in an algo element
#let _algo-indent-key = "_algo-indent"

// counter to mark the page that each line in an algo element is on
#let _algo-current-page-key = "_algo-current-page"

// counter to mark the page that each line in a code element is on
#let _code-current-page-key = "_code-current-page"

// state value for storing algo comments
#let _algo-comment-lists = state("_algo-comment-lists", ())

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


// Get the thickness of a stroke.
// Credit to PgBiel on GitHub.
#let _stroke-thickness(stroke) = {
  // TODO: When it is possible to access the thickness of any
  //   stroke value, remove this function.

  if type(stroke) in ("length", "relative length") {
    stroke
  } else if type(stroke) == "color" {
    1pt
  } else if type(stroke) == "stroke" {
    let r = regex("^\\d+(?:em|pt|cm|in|%)")
    let s = repr(stroke).find(r)

    if s == none {
      1pt
    } else {
      eval(s)
    }
  } else if type(stroke) == "dictionary" and "thickness" in stroke {
    stroke.thickness
  } else {
    1pt
  }
}


// Given a line in an algo or code, creates the
//   indent guides that should appear on that line.
#let _indent-guides(
  line,
  stroke,
  indent-level,
  indent-size,
  block-inset,
  row-gutter,
  is-header-empty,
  is-first-line,
  is-last-line,
  page-counter-key,
) = {
  // TODO: Replace rect calls with line when the compiler errors
  //   go away.

  let page-counter = counter(page-counter-key)
  let guide-width = _stroke-thickness(stroke)

  locate(loc => {
    let current-page = loc.page()

    style(styles => {
      let inset-pt = measure(
        rect(width: block-inset),
        styles
      ).width

      let row-gutter-pt = measure(
        rect(width: row-gutter),
        styles
      ).width

      let line-height = measure(line, styles).height

      let text-height = measure(
        [ABCDEFGHIJKLMNOPQRSTUVWXYZ],
        styles
      ).height

      let cell-height = calc.max(line-height, text-height)

      page-counter.display(pg => {
        let backset = none

        if (
          (
            is-first-line and
            is-header-empty
          ) or
          pg != current-page
        ) {
          backset = calc.min(inset-pt, row-gutter-pt) / 2
        } else {
          backset = row-gutter-pt / 2
        }

        for j in range(1, indent-level + 1) {
          place(
            dx: indent-size * (j - 1) + guide-width / 2 + 0.5pt,
            dy: -backset,
            rect(
              width: 0pt,
              height: cell-height + backset + (
                if is-last-line {
                  calc.min(inset-pt / 2, cell-height / 5)
                } else {
                  row-gutter-pt / 2
                }
              ),
              stroke: stroke
            )
          )
        }
      })
    })

    page-counter.update(current-page)
  })
}


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


// Adds a comment to a line in an algo body.
//
// Parameters:
//   body: Comment content.
#let comment(body) = {
  _algo-comment-lists.update(comment-lists => {
    comment-lists.last().last() += body
    comment-lists
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
//   comment-prefix: Content to prepend comments with.
//   comment-color: Font color for comments.
//   indent-size: Size of line indentations.
//   indent-guides: Stroke for indent guides.
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
  comment-prefix: "// ",
  comment-color: rgb(45%, 45%, 45%),
  indent-size: 20pt,
  indent-guides: none,
  row-gutter: 10pt,
  column-gutter: 10pt,
  inset: 10pt,
  fill: rgb(98%, 98%, 98%),
  stroke: 1pt + rgb(50%, 50%, 50%)
) = {
  // TODO: Make this an element function when possible.
  // TODO: When it is possible to make this an element function,
  //   change comment state to only track comments for most
  //   recent instance of algo, and query state at first algo
  //   after current location.

  set par(justify: false)

  counter(_algo-counter-key).step()
  counter(_algo-indent-key).update(0)

  _algo-comment-lists.update(comment-lists => {
    comment-lists.push(())
    comment-lists
  })

  locate(
    loc => counter(_algo-current-page-key).update(loc.page())
  )

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
  // TODO: Remove this, probably.
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

  // build text and comment lists
  let steps = ()

  for (i, line) in lines.enumerate() {
    let formatted-line = {
      show regex("\S+"): it => {
        if strong-keywords and it in keywords {
          strong(it)
        } else {
          it
        }
      }

      _algo-comment-lists.update(comment-lists => {
        comment-lists.last().push([])
        comment-lists
      })

      counter(_algo-indent-key).display(n => {
        if indent-guides != none {
          _indent-guides(
            line,
            indent-guides,
            n,
            indent-size,
            inset,
            row-gutter,
            if title == none and parameters == () {
              true
            } else {
              false
            },
            i == 0,
            i == lines.len() - 1,
            _algo-current-page-key,
          )
        }

        pad(
          left: indent-size * n,
          line
        )
      })
    }

    steps.push(formatted-line)
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

  // build table
  let algo-table = locate(loc => {
    let comment-list = _algo-comment-lists.final(loc).at(
      counter(_algo-counter-key).at(loc).at(0) - 1
    )

    let num-columns = 1
    let has-comments = comment-list.any(e => e != [])

    if line-numbers and has-comments {
      num-columns = 3
    } else if line-numbers or has-comments {
      num-columns = 2
    }

    let table-data = ()

    for (i, line) in steps.enumerate() {
      if line-numbers {
        let line-number = i + 1
        table-data.push([#line-number])
      }

      table-data.push(line)

      if has-comments {
        if comment-list.at(i) != [] {
          table-data.push({
            set text(fill: comment-color)
            comment-prefix
            comment-list.at(i)
          })
        } else {
          table-data.push([])
        }
      }
    }

    table(
      columns: num-columns,
      column-gutter: column-gutter,
      row-gutter: row-gutter,
      align: if line-numbers and has-comments {
        (x, _) => (right+horizon, left, left+horizon).at(x)
      } else if line-numbers {
        (x, _) => (right+horizon, left).at(x)
      } else {
        left
      },
      stroke: none,
      inset: 0pt,
      ..table-data
    )
  })

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
    #align(left, algo-table)
  ])
}


// Displays code in a block element.
// Credit to Dherse on GitHub for the code
//   to display raw text with line numbers.
//
// Parameters:
//   body: Raw text.
//   line-numbers. Whether to have line numbers.
//   indent-guides: Stroke for indent guides.
//   tab-size: Amount of spaces that should be considered an indent.
//     Set to none if you intend to use tab characters.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding.
//   fill: Fill color.
//   stroke: Border stroke.
#let code(
  body,
  line-numbers: true,
  indent-guides: none,
  tab-size: 2,
  row-gutter: 10pt,
  column-gutter: 10pt,
  inset: 10pt,
  fill: rgb(98%, 98%, 98%),
  stroke: 1pt + rgb(50%, 50%, 50%)
) = {
  // TODO: Make this an element function when possible.

  set par(justify: false)

  locate(
    loc => counter(_code-current-page-key).update(loc.page())
  )

  let table-data = ()
  let raw-children = body.children.filter(e => e.func() == raw)
  let line-number = 1

  for (i, child) in raw-children.enumerate() {
    if child.func() == raw {
      let lines = child.text.split("\n")

      for (j, line) in lines.enumerate() {
        if line-numbers {
          table-data.push(str(line-number))
        }

        let raw-line = raw(line, lang: child.lang)

        let content = {
          if indent-guides != none {
            style(styles => {
              let indent-level = 0
              let indent-size = 0

              if tab-size == none {
                let whitespace = line.match(regex("^(\t*).*$")).at("captures").at(0)
                indent-level = whitespace.len()
                indent-size = measure(raw("\t"), styles).width
              } else {
                let whitespace = line.match(regex("^( *).*$")).at("captures").at(0)
                indent-level = calc.floor(whitespace.len() / tab-size)
                indent-size = measure(raw("a" * tab-size), styles).width
              }

              _indent-guides(
                raw-line,
                indent-guides,
                indent-level,
                indent-size,
                inset,
                row-gutter,
                true,
                i == 0,
                i == raw-children.len() - 1 and j == lines.len() - 1,
                _code-current-page-key,
              )
            })
          }

          raw-line
        }

        table-data.push(content)
        line-number += 1
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
      align: if line-numbers {
        (x, _) => (right+horizon, left).at(x)
      } else {
        left
      },
      ..table-data
    )
  ])
}
