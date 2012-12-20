# Rainy

Rainy is a simple front-end module solution. It just **inline** all js / css you need into the HTML / js.

## First Example

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

Put jquery and jquery-cookie into `~/jslibs`, then run:

```bash
~/rainy/rain --incpath "~/jslibs" --moddef test.moddef input.htm
```

output:

```html
<div>other parts</div>
<script type="text/javascript">
...... // code from jquery
;
...... // code from jquery-cookie
</script>
</body>
```

## More Examples

See living examples from my other javascript projects:

* [base.js](https://github.com/henix/base.js/blob/master/base.moddef)
* [flower.js](https://github.com/henix/flower.js/blob/master/flower.moddef)
* [flower-widgets](https://github.com/henix/flower-widgets/blob/master/flowerui.moddef)

## Syntax of .moddef files

### Define a module

```ruby
ModuleA: file.js
ModuleA: file.js file.css # a module with css
ModuleA: # this equals to "ModuleA: ModuleA.js", rainy will use module name plus ".js" as file name
```

### Define dependencies

```ruby
ModuleA -> ModuleB ModuleC # separate dependencies with spaces
```

### Define submodules in dir

```ruby
dir ModuleA ModuleADir {
	Submodule1:
	Submodule2:
	Submodule2 -> Submodule1
}
```

Above code using `dir` is a shortcut form of following code:

```ruby
ModuleA.Submodule1: ModuleADir/Submodule1.js
ModuleA.Submodule2: ModuleADir/Submodule2.js
ModuleA.Submodule2 -> ModuleA.Submodule1

ModuleA -> ModuleA.Submodule1 ModuleA.Submodule2 # a special module with the dir's name and depends on all of its submodules
```

## Rainy command line options

* --incpath : add an include path
* --moddef : load a .moddef file

## Install

Rainy is written in Lua. It requires Lua **5.2** or luajit (because it uses `coroutine.yield` within `pcall`, which Lua 5.1 not supported).

## Advantages

Compared to other module system (AMD / CMD / require.js / sea.js)

* No changes are required for existing javascript
* Significantly reduce number of HTTP request

Compared to other js preprocessor (cpp / jspp, they use #include / #define / #ifndef)

* Rainy focus on declaring modules and dependencies, which is a higher layer than macro expanding

## Limitations

Rainy currently doesn't detect cyclic dependencies. If you specify a cyclic dependency, the order of inlined code will be uncertain.

## Complete grammar(EBNF) of .moddef files

See comments in [rainy/moddef.lua](https://github.com/henix/rainy/blob/master/rainy/moddef.lua)
