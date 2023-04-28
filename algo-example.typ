#import "algo.typ" : *


// check out algo.typ to see all the options
#algo(
  title: "Fib",             // title and parameters are optional
  parameters: ("n",),
  strong-keywords: true     // bold keywords
)[
  if $n < 0$:#i\            // use #i to indent the following lines
    return null#d\          // use #d to to dedent the following lines

  if $n = 0$ or $n = 1$:#i #comment[you can also]\
    return $n$#d #comment[add comments!]\
  return #smallcaps("Fib")$(n-1) +$ #smallcaps("Fib")$(n-2)$
]


#code()[
  ```py
  def fib(n):
    if n < 0:
      return None
    if n == 0 or n == 1:
      return n
    return fib(n-1) + fib(n-2)
  ```
]
