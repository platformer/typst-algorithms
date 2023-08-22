#import "../../algo.typ": algo, i, d, comment

#algo(
  title: "Fib",
  parameters: ("n",)
)[
  if $n < 0$:#i\
    return null#d\
  if $n = 0$ or $n = 1$:#i #comment[you can also]\
    return $n$#d#d #comment[add comments!]\ // excess dedent on this line
  return #smallcaps("Fib")$(n-1) +$ #smallcaps("Fib")$(n-2)$
]
