// check out the README to see all the options
// for algo and code
#import "../algo.typ": algo, i, d, comment, code


#algo(
  title: "Fib",
  parameters: ("n",)
)[
  if $n < 0$:#i\        // use #i to indent the following lines
    return null#d\      // use #d to dedent the following lines
  if $n = 0$ or $n = 1$:#i #comment[you can also]\
    return $n$#d #comment[add comments!]\
  return #smallcaps("Fib")$(n-1) +$ #smallcaps("Fib")$(n-2)$
]


#v(3em)


#algo(
  line-numbers: false,
  keyword-styles: false
)[
  if $n < 0$:#i\
    return null#d\
  if $n = 0$ or $n = 1$:#i\
    return $n$#d\
  \
  let $x <- 0$\
  let $y <- 1$\
  for $i <- 2$ to $n-1$:#i #comment[so dynamic!]\
    let $z <- x+y$\
    $x <- y$\
    $y <- z$#d\
    \
  return $x+y$
]


#v(3em)


#algo(
  title: [                    // note that title and parameters
    #set text(size: 15pt)     // can be content
    #emph(smallcaps("Fib"))
  ],
  parameters: ([#math.italic("n")],),
  comment-prefix: [#sym.triangle.stroked.r ],
  comment-styles: (fill: rgb(100%, 0%, 0%)),
  indent-size: 15pt,
  indent-guides: 1pt + gray,
  row-gutter: 5pt,
  column-gutter: 5pt,
  inset: 5pt,
  stroke: 2pt + black,
  fill: none,
  keyword-styles: x => text(blue, x)
)[
  if $n < 0$:#i\
    return null#d\
  if $n = 0$ or $n = 1$:#i\
    return $n$#d\
  \
  let $x <- 0$\
  #comment(inline: true)[for instance]\
  #comment[for instance]\
  #box(stroke: black, inset: 2pt)[for]\
  let $y <- 1$\
  for $i <- 2$ to $n-1$:#i #comment[so dynamic!]\
    let $z <- x+y "if" x != 0$\
    $x <- y$\
    $y <- z$#d\
    \ \
  return $x+y$
]


#pagebreak()


#code()[
  ```py
  def fib(n):
    if n < 0:
      return None
    if n == 0 or n == 1:        # this comment is
      return n                  # normal raw text
    return fib(n-1) + fib(n-2)
  ```
]


#v(3em)


#code(
  indent-guides: 1pt + gray,
  row-gutter: 5pt,
  column-gutter: 5pt,
  inset: 5pt,
  stroke: 2pt + black,
  fill: none,
)[
  ```py
  def fib(n):
      if n < 0:
          return None
      if n == 0 or n == 1:        # this comment is
          return n                # normal raw text
      return fib(n-1) + fib(n-2)
  ```
]
