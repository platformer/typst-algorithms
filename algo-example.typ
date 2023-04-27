#import "algo.typ" : *


// check out algo.typ to see all the options
#algo(
  title: "Fibonacci",       // title and parameters are optional
  parameters: ("n",),
  strong-keywords: true     // bold keywords
)[
  if $n < 0$:#i\            // use #i to indent the following lines
    return null#d\          // use #d to to dedent the following lines
  if $n = 0$ or $n = 1$:#i\
    return $n$#d\
  return #smallcaps("Fibonacci")$(n-1) +$ #smallcaps("Fibonacci")$(n-2)$
]


#code()[
  ```py
  def fibonacci(n):
    if n < 0:
      return None
    if n == 0 or n == 1:
      return n
    return fibonacci(n-1) + fibonacci(n-2)
  ```
]
