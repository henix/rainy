# Rainy

Rainy is a simple front-end module solution. It just *inline* all js / css you need into the HTML / js.

## Input and output

input: module and dependency define

output: inlined HTML or js

## A simple example

test.moddef - define modules and dependencies:

```ruby
JQuery.cookie: jquery-cookie/jquery-cookie.js
JQuery: jquery/jquery.js

JQuery.cookie -> JQuery # declare that JQuery-cookie depends on JQuery, add comments like this
```

the html

```html
<div>other parts</div>
#inline JQuery.cookie
</body>
```

run:

```bash
~/rainy/rain --incpath "~/jslibs" --moddef test.moddef input.htm
```

output:

```html
<div>other parts</div>
<script type="text/javascript">
...... // code from jquery
...... // code from jquery-cookie
</script>
</body>
```

## Install

Rainy is written in Lua. It requires Lua *5.2* or luajit (because it uses `coroutine.yield` within `pcall`, which Lua 5.1 not supported).

## Advantages

Compared to other module system (AMD / CMD / require.js / sea.js)

* No changes are required for existing javascript
* Significantly reduce number of HTTP request

Compared to other js preprocessor (cpp / jspp, they use #include / #define / #ifndef)

* Rainy focus on declaring modules and dependencies, which is a higher layer than macro expanding

## Limitations

Rainy currently doesn't detect cyclic dependencies. If you specify a cyclic dependency, the order of inlined code will be uncertain.

## Grammar of .moddef files

See comments in [rainy/moddef.lua](https://github.com/henix/rainy/blob/master/rainy/moddef.lua)
