As if the internet needed yet another one, anthill is a static website generator. It takes a directory of plaintext files (formatted with [markdown](https://daringfireball.net/projects/markdown/syntax)) as input, and spits out .html files ready for browsing. Much like with [werc](http://werc.cat-v.org/), navigation between pages is facilitated by automatically generated lists of directory contents. There are no databases or external configuration files. anthill is a single command that will run against extant files and return a website from them. 

## Requirements

+ [Chicken Scheme v. 5](http://www.call-cc.org/): The Scheme dialect anthill is written in.
+ [Discount](http://www.pell.portland.or.us/~orc/Code/discount/): The specific markdown implementation used to format files. It's written in C, so it's much faster than the default Perl script. Other versions are not guaranteed to work with anthill, but the program will attempt to use whichever ``markdown`` you have in your path.

## Installation

+ `make` (may have to be root to install Chicken extensions)
+ `make install` (may have to be root here too)
+ `make uninstall` (to remove)

## Usage

anthill takes arguments in the form `-parameter "value"`. Those parameters are as follows:

+ `css:` Link to the URL of the CSS file that will style the site.
+ `delimiter:` The text that will appear between the site name and page name in the banner.
+ `hidden:` The navigation bar can be hidden behind a button. This is the text that appears on that button.
+ `inline-css:` The local CSS file that will be inlined directly into the header. Overrules the `css` parameter.
+ `input:` The root directory containing the main content of the site, formatted as Markdown. Will default to current directory.
+ `markdown:` Alternative markdown command. Can be path to a different markdown executable, or invocation with certain paramerters, etc. Must contain the markdown command itself (ie -markdown "markdown -F 0x4").
+ `minify:` Removes all newlines from output, increasing transfer speed. Whitespace within <code\> is still honored. The parameter to this option can technically be anything; both `-minify "yes"` and `-minify "no"` will have the same effect. Simply don't use this option if you wish to preserve newlines.
+ `name:` The site's name, visible in the banner at the top of every page.
+ `output:` The directory root of the HTML output. Will default to /tmp/anthill-output.
+ `url:` The root URL for the section of the website served by anthill. Will default to the local filesystem.

Sites managed by anthill maintain no external state. I reccomend adding an alias with one's preferred settings per site. My .bash_profile has this line in it, for instance:

    alias jimjimjim='"/usr/local/bin/anthill" -input "/path/to/input" -output "/path/to/output" -url "https://dalrym.pl/media/code/scheme/anthill-demo" -inline-css "/path/to/style.css" -markdown "markdown -F 0x4" -hidden "▼ navigation" -minify "yes"

## Behavior

Navigation of the site mirrors directory hierarchy. Move a file in your input directory to move it on your site. 

All pages in a directory are listed in alphabetical order, just like in regular filesystem navigation. Subdirectories are represented by pages named " directory" (notice the literal whitespace) that are automatically generated the first time anthill encounters them. Their contents can be edited like any other page. Input files whose names begin with whitespace have special treatment, so please don't add your own. 

anthill includes a few tags with its generated html:

+ ``#banner:`` a div id for the title displayed at the top of every page.
+ ``#sitename:`` a span id for styling the name of the site.
+ ``#delimiter:`` a span id for styling the delimiter that separates the site name from the current page name
+ ``#pagename:`` a span id for styling the name of the current page.
+ ``#toggle:`` an id that can be used to toggle the navigation bar as visible/invisible. This is useful for mobile layouts.
+ ``.expand:`` a class assigned to the navigation bar that is used to toggle its visibility. 
+ ``#nav:`` an id that contains the site's navigation bar.
+ ``.path:`` a class used to point out the directory path to the active file.
+ ``.unpath:`` a class used for any file or folder outside of the path.
+ ``#main:`` an id that contains the main content of a given page, generated from the user's markdown files

Without any real sense for web design, I'm not sure if the elements provided are verbose or paltry. All I know is that I've managed to eek out a passable layout from them. I've included an example css file. I know you can do better.

anthill is not intelligent. When invoked, it will not check which files need to be updated. It will simply copy everything from the input directory into the output directory, overwriting whatever crosses its path. This makes sense in a way; every file should be recreated at the same time in order to ensure the consistency of the navigation tree. Non-HTML files in the output directory won't be modified by anthill, so you can keep images, videos, etc there too.
 
## Toggling navigation visibility

For certain layouts, especially mobile ones, it might make sense to keep the navigation tree hidden by default. I used [Adrian Roselli's](http://adrianroselli.com/2015/07/showhide-script-free-which-means-css-only.html) method to do this in css alone. The user need only place the following in the site stylesheet:

    .expand {display:none;}
    .expand:target {display:block;}

and the navigation will show up when the user clicks on the text specified by the ``-hidden`` argument.

## Demo

It's not pretty, but you can see it in action [here](https://dalrym.pl/media/code/scheme/anthill-demo/index.html).

## Acknowledgements

+ Adrian Roselli for the aforementioned hack.
+ [UTF-8 Everywhere](http://utf8everywhere.org/) for the beautiful css layout I shamelessly co-opted.
