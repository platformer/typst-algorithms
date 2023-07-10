# Algo

A Typst library for writing algorithms. On Typst v0.6.0+ you can import the `algo` package:

```typst
#import "@preview/algo:0.2.0": algo, i, d, comment, code
```

Otherwise, add the `algo.typ` file to your project and import it as normal:

```typst
#import "algo.typ": algo, i, d, comment, code
```

Use the `algo` function for writing pseudocode and the `code` function for writing code blocks with line numbers. Check out the examples below to see how they work. `algo.typ` also has comments explaining the options each function has.

## Examples

Here's a basic use of `algo`:

```typst
#algo(
  title: "Fib",
  parameters: ("n",)
)[
  if $n < 0$:#i\        // use #i to indent the following lines
    return null#d\      // use #d to to dedent the following lines
  if $n = 0$ or $n = 1$:#i #comment[you can also]\
    return $n$#d #comment[add comments!]\
  return #smallcaps("Fib")$(n-1) +$ #smallcaps("Fib")$(n-2)$
]
```

<img src="https://user-images.githubusercontent.com/40146328/235323240-e59ed7e2-ebb6-4b80-8742-eb171dd3721e.png" width="400px" />

<br />

Here's a use of `algo` without a title, parameters, line numbers, or syntax highlighting:

```typst
#algo(
  line-numbers: false,
  strong-keywords: false
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
```

<img src="https://user-images.githubusercontent.com/40146328/235323261-d6e7a42c-ffb7-4c3a-bd2a-4c8fc2df5f36.png" width="300px" />

<br />

And here's `algo` with more styling options:

```typst
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
```

<img src="https://github.com/platformer/typst-algorithms/assets/40146328/89f80b5d-bdb2-420a-935d-24f43ca597d8" width="300px" />

&nbsp;

Here's a basic use of `code`:

````typst
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
````

<img src="https://user-images.githubusercontent.com/40146328/235324088-a3596e0b-af90-4da3-b326-2de11158baac.png" width="400px"/>

<br />

And here's `code` with some styling options:

````typst
#code(
  tab-size: 4,  // sets how many spaces to interpret as one indent
                // use none if you are using real tab characters
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
````

<img src="https://github.com/platformer/typst-algorithms/assets/40146328/c091ac43-6861-40bc-8046-03ea285712c3" width="400px"/>

## Contributing

PRs are welcome! And if you encounter any bugs or have any requests/ideas, feel free to open an issue.
