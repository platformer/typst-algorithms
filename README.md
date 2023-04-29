# typst-algorithms

Typst module for writing algorithms. To use it, add the `algo.typ` file to your project. Then, import everything from `algo.typ` into your document:

```typst
#import "algo.typ" : *
```

Use the `algo` function for writing pseudocode and the `code` function for writing code blocks with line numbers. Check out the examples below to see how they work. `algo.typ` also has comments explaining the options each function has.

## Examples

Here's a basic use of `algo`:

<table>
<tr>
<td>

```typst
#algo(
  title: "Fib",         // title and parameters are optional
  parameters: ("n",),
  strong-keywords: true // bold keywords
)[
  if $n < 0$:#i\    // use #i to indent the following lines
    return null#d\  // use #d to to dedent the following lines
  if $n = 0$ or $n = 1$:#i #comment[you can also]\
    return $n$#d #comment[add comments!]\
  return #smallcaps("Fib")$(n-1) +$ #smallcaps("Fib")$(n-2)$
]
```

</td>
<td align="center">
<img src="https://user-images.githubusercontent.com/40146328/235323240-e59ed7e2-ebb6-4b80-8742-eb171dd3721e.png" />
</td>
</tr>
</table>

<br />

Here's a use of `algo` without a title, parameters, line numbers, or syntax highlighting:

<table>
<tr>
<td>

```typst
#algo(
  line-numbers: false
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

</td>
<td align="center">
<img src="https://user-images.githubusercontent.com/40146328/235323261-d6e7a42c-ffb7-4c3a-bd2a-4c8fc2df5f36.png" width="80%" />
</td>
</tr>
</table>

<br />

And here's `algo` with some more styling options:

<table>
<tr>
<td>

```typst
#algo(
  title: [                  // title and parameters
    #set text(size: 15pt)   // can be content
    #emph(smallcaps("Fib"))
  ],
  parameters: ([#math.italic("n")],),
  strong-keywords: true,
  comment-prefix: [#sym.triangle.stroked.r ],
  comment-color: rgb(100%, 0%, 0%),
  inset: 5pt,
  row-gutter: 5pt,
  column-gutter: 5pt,
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

</td>
<td align="center">
<img src="https://user-images.githubusercontent.com/40146328/235323500-00ee9771-53d0-4d9e-811b-f1729832155e.png" />
</td>
</tr>
</table>

<br />

Here's a basic use of `code`:

<table>
<tr>
<td>

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

</td>
<td align="center">
<img src="https://user-images.githubusercontent.com/40146328/235324088-a3596e0b-af90-4da3-b326-2de11158baac.png" />
</td>
</tr>
</table>

<br />

And here's `code` with some styling options:

<table>
<tr>
<td>

````typst
#code(
  inset: 5pt,
  row-gutter: 5pt,
  column-gutter: 5pt,
  stroke: 2pt + black,
  fill: none,
)[
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

</td>
<td align="center">
<img src="https://user-images.githubusercontent.com/40146328/235324247-08438d8b-822a-4795-a78b-a56b95a1c0c0.png" />
</td>
</tr>
</table>

## Contributing

PRs are welcome! And if you encounter any bugs or have any requests/ideas, feel free to open an issue!
