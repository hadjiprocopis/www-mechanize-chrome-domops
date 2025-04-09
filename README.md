# NAME

WWW::Mechanize::Chrome::DOMops - Operations on the DOM loaded in Chrome

# VERSION

Version 0.10

# SYNOPSIS

This module provides a set of tools to operate on the DOM
loaded onto the provided [WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome) object
after fetching a URL.

Operating on the DOM is powerful but there are
security risks involved if the browser and profile
you used for loading this DOM is your everyday browser and profile.

Please read ["SECURITY WARNING"](#security-warning) before continuing on to the main course.

Currently, [WWW::Mechanize::Chrome::DOMops](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%3A%3ADOMops) provides these tools:

- `find()` : finds HTML elements,
- `zap()` : deletes HTML elements.

Both `find()` and `zap()` return some information from
each match and its descendents (like `tag`, `id` etc.).
This information can be tweaked by the caller.
`find()` and `zap()` optionally execute javascript code on
each match and its descendents and can return data back to
the caller perl code.

The selection of the HTML elements in the DOM
can be done in various ways:

- by **CSS selector**,
- by **tag**,
- by **class**.
- by **id**,
- by **name**.

There is more information about this in section ["ELEMENT SELECTORS"](#element-selectors).

Here are some usage scenaria:

      use WWW::Mechanize::Chrome::DOMops qw/zap find VERBOSE_DOMops/;

      # adjust verbosity: 0, 1, 2, 3
      $WWW::Mechanize::Chrome::VERBOSE_DOMops = 3;

      # First, create a mech object and load a URL on it
      # Note: you need google-chrome binary installed in your system!
      # See section CREATING THE MECH OBJECT for creating the mech
      # and how to redirect its javascript console to perl's output
      my $mechobj = WWW::Mechanize::Chrome->new();
      # fetch a page which will setup a DOM on which to operate:
      $mechobj->get('https://www.bbbbbbbbb.com');

      # find elements in the DOM, select by id, tag, name, or 
      # by CSS selector.
      my $ret = find({
         'mech-obj' => $mechobj,
         # find elements whose class is in the provided
         # scalar class name or array of class names
         'element-class' => ['slanted-paragraph', 'class2', 'class3'],
         # *OR* their tag is this:
         'element-tag' => 'p',
         # *OR* their name is this:
         'element-name' => ['aname', 'name2'],
         # *OR* their id is this:
         'element-id' => ['id1', 'id2'],
         # *OR* just provide a CSS selector and get done with it already
         # the best choice
         'element-cssselector' => 'a-css-selector',
         # specifies that we should use the union of the above sets
         # hence the *OR* in above comment
         '||' => 1,
         # this says to find all elements whose class
         # is such-and-such AND element tag is such-and-such
         # '&&' => 1 means to calculate the INTERSECTION of all
         # individual matches.

         # build the information sent back from each match
         'element-information-from-matched' => <<'EOJ',
  // begin JS code to extract information from each match and return it
  // back as a hash
  const r = htmlElement.hasAttribute("role")
    ? htmlElement.getAttribute("role") : "<no role present>"
  ;
  return {"tag" : htmlElement.tagName, "id" : htmlElement.id, "role" : r};
  EOJ
         # optionally run javascript code on all those elements matched
         'find-cb-on-matched' => [
           {
             'code' =><<'EOJS',
    // the element to operate on is 'htmlElement'
    console.log("operating on this element "+htmlElement.tagName);
    // this is returned back in the results of find() under
    // key "cb-results"->"find-cb-on-matched"
    return 1;
  EOJS
             'name' => 'func1'
           }, {...}
         ],
         # optionally run javascript code on all those elements
         # matched AND THEIR CHILDREN too!
         'find-cb-on-matched-and-their-children' => [
           {
             'code' =><<'EOJS',
    // the element to operate on is 'htmlElement'
    console.log("operating on this element "+htmlElement.tagName);
    // this is returned back in the results of find() under
    // key "cb-results"->"find-cb-on-matched" notice the complex data
    return {"abc":"123",{"xyz":[1,2,3]}};
  EOJS
             'name' => 'func2'
           }
         ],
         # optionally ask it to create a valid id for any HTML
         # element returned which does not have an id.
         # The text provided will be postfixed with a unique
         # incrementing counter value 
         'insert-id-if-none' => '_prefix_id',
         # or ask it to randomise that id a bit to avoid collisions
         'insert-id-if-none-random' => '_prefix_id',

         # optionally, also output the javascript code to a file for debugging
         'js-outfile' => 'output.js',
      });


      # Delete an element from the DOM
      $ret = zap({
         'mech-obj' => $mechobj,
         'element-id' => 'paragraph-123'
      });

      # Mass murder:
      $ret = zap({
         'mech-obj' => $mechobj,
         'element-tag' => ['div', 'span', 'p'],
         '||' => 1, # the union of all those matched with above criteria
      });

      # error handling
      if( $ret->{'status'} < 0 ){ die "error: ".$ret->{'message'} }
      # status of -3 indicates parameter errors,
      # -2 indicates that eval of javascript code inside the mech object
      # has failed (syntax errors perhaps, which could have been introduced
      # by user-specified callback
      # -1 indicates that javascript code executed correctly but
      # failed somewhere in its logic.

      print "Found " . $ret->{'status'} . " matches which are: "
      # ... results are in $ret->{'found'}->{'first-level'}
      # ... and also in $ret->{'found'}->{'all-levels'}
      # the latter contains a recursive list of those
      # found AND ALL their children

# EXPORT

the sub to find element(s) in the DOM

    find()

the sub to delete element(s) from the DOM

    zap()

and the flag to denote verbosity (default is 0, no verbosity)

    $WWW::Mechanize::Chrome::DOMops::VERBOSE_DOMops

# SUBROUTINES/METHODS

## find($params)

It finds HTML elements in the DOM currently loaded on the
parameters-specified [WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome) object. The
parameters are:

- `mech-obj` : user must supply a [WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome) object,
this is required. See section
["CREATING THE MECH OBJECT"](#creating-the-mech-object) for an example of creating the mech object with some parameters
which work for me and javascript console output propagated on to perl's output.
- `element-information-from-matched` : optional javascript code to be run
on each HTML element matched in order to construct the information data
whih is returned back. If none
specified the following default will be used, which returns tagname and id:

        // the matched element is provided in htmlElement
        return {"tag" : htmlElement.tagName, "id" : htmlElement.id};

    Basically the code is expected to be the **body of a function** which
    accepts one parameter: `htmlElement` (that is the element matched).
    That means it **must not have**
    the function preamble (function name, signature, etc.).
    Neither it must have the postamble, which is the end-block curly bracket.
    This piece of code **must return a HASH**. 
    The code can throw exceptions which will be caught
    (because the code is run within a try-catch block)
    and the error message will be propagated to the perl code with status of -1.

- `insert-id-if-none` : some HTML elements simply do not have
an id (e.g. `<p`>). If any of these elements is matched,
its tag and its id (empty string) will be returned.
By specifying this parameter (as a string, e.g. `_replacing_empty_ids`)
all such elements matched will have their id set to
`_replacing_empty_ids_X` where X is an incrementing counter
value starting from a random number. By running `find()`
more than once on the same on the same DOM you are risking
having the same ID. So provide a different prefix every time.
Or use `insert-id-if-none-random`, see below.
- `insert-id-if-none-random` : each time `find()` is called
a new random base id will be created formed by the specified prefix (as with
`insert-id-if-none`) plus a long random string plus the incrementing
counter, as above. This is supposed to be better at
avoiding collisions but it can not guarantee it.
If you are setting `rand()`'s seed to the same number
before you call `find()` then you are guaranteed to
have collisions.
- `find-cb-on-matched` : an array of
user-specified javascript code
to be run on each element matched in the order
the elements are returned and in the order of the javascript
code in the specified array. Each item of the array
is a hash with keys `code` and `name`. The former
contains the code to be run assuming that the
html element to operate on is named `htmlElement`.
The code must end with a `return` statement which
will be recorded and returned back to perl code.
The code can throw exceptions which will be caught
(because the callback is run within a try-catch block)
and the error message will be propagated to the perl code with status of -1.
Basically the code is expected to be the **body of a function** which
accepts one parameter: `htmlElement` (that is the element matched).
That means it **must not have**
the function preamble (function name, signature, etc.).
Neither it must have the postamble, which is the end-block curly bracket.

    Key `name` is just for
    making this process more descriptive and will
    be printed on log messages and returned back with
    the results. `name` can contain any characters.
    Here is an  example:

        'find-cb-on-matched' : [
          {
            # this returns a complex data type
            'code' => 'console.log("found id "+htmlElement.id); return {"a":"1","b":"2"};'
            'name' => 'func1'
          },
          {
            'code' => 'console.log("second func: found id "+htmlElement.id); return 1;'
            'name' => 'func2'
          },
        ]

- `find-cb-on-matched-and-their-children` : exactly the same
as `find-cb-on-matched` but it operates on all those HTML elements
matched and also all their children and children of children etc.
- `js-outfile` : optionally save the javascript
code (which is evaluated within the mech object) to a file.
- `element selectors` are covered in section ["ELEMENT SELECTORS"](#element-selectors).

**JAVASCRIPT HELPERS**

There is one javascript function available to all user-specified callbacks:

- `getAllChildren(anHtmlElement)` : it returns
back an array of HTML elements which are the children (at any depth)
of the given `anHtmlElement`.

**RETURN VALUE**:

The returned value is a hashref with at least a `status` key
which is greater or equal to zero in case of success and
denotes the number of matched HTML elements. Or it is -3, -2 or
\-1 in case of errors:

- `-3` : there is an error with the parameters passed to this sub.
- `-2` : there is a syntax error in the javascript code to be
evaluated by the mech object with something like `$mech_obj-`eval()>.
Most likely this syntax error is with user-specified callback code.
Note that all the javascript code to be evaluated is dumped to stderr
by increasing the verbosity. But also it can be saved to a local file
for easier debugging by supplying the `js-outfile` parameter to
`find()` or `zap()`.
- `-1` : there is a logical error while running the javascript code.
For example a division by zero etc. This can be both in the callback code
as well as in the internal javascript code for edge cases not covered
by my tests. Please report these.
Note that all the javascript code to be evaluated is dumped to stderr
by increasing the verbosity. But also it can be saved to a local file
for easier debugging by supplying the `js-outfile` parameter to
`find()` or `zap()`.

If `status` is not negative, then this is success and its value
denotes the number of matched HTML elements. Which can be zero
or more. In this case the returned hash contains this

    "found" => {
      "first-level" => [
        {
          "tag" => "NAV",
          "id" => "nav-id-1"
        }
      ],
      "all-levels" => [
        {
          "tag" => "NAV",
          "id" => "nav-id-1"
        },
        {
          "id" => "li-id-2",
          "tag" => "LI"
        },
      ]
    }

Key `first-level` contains those items matched directly while
key `all-levels` contains those matched directly as well as those
matched because they are descendents (direct or indirect)
of each matched element.

Each item representing a matched HTML element has two fields:
`tag` and `id`. Beware of missing `id` or
use `insert-id-if-none` or `insert-id-if-none-random` to
fill in the missing ids.

If `find-cb-on-matched` or `find-cb-on-matched-and-their-children`
were specified, then the returned result contains this additional data:

    "cb-results" => {
       "find-cb-on-matched" => [
         [
           {
             "name" => "func1",
             "result" => {
               "a" => 1,
               "b" => 2
             }
           }
         ],
         [
           {
             "result" => 1,
             "name" => "func2"
           }
         ]
       ],
       "find-cb-on-matched-and-their-children" => ...
     },

`find-cb-on-matched` and/or `find-cb-on-matched-and-their-children` will
be present depending on whether corresponding value in the input
parameters was specified or not. Each of these contain the return
result for running the callback on each HTML element in the same
order as returned under key `found`.

HTML elements allows for missing `id`. So field `id` can be empty
unless caller set the `insert-id-if-none` input parameter which
will create a unique id for each HTML element matched but with
missing id. These changes will be saved in the DOM.
When this parameter is specified, the returned HTML elements will
be checked for duplicates because now all of them have an id field.
Therefore, if you did not specify this parameter results may
contain duplicate items and items with empty id field.
If you did specify this parameter then some elements of the DOM
(those matched by our selectors) will have their missing id
created and saved in the DOM.

Another implication of using this parameter when
running it twice or more with the same value is that
you can get same ids. So, always supply a different
value to this parameter if run more than once on the
same DOM.

## zap($params)

It removes HTML element(s) from the DOM currently loaded on the
parameters-specified [WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome) object. The params
are exactly the same as with ["find($params)"](#find-params) except that
`insert-id-if-none` is ignored.

`zap()` is implemented as a `find()` with
an additional callback for all elements matched
in the first level (not their children) as:

    'find-cb-on-matched' => {
      'code' => 'htmlElement.parentNode.removeChild(htmlElement); return 1;',
      'name' => '_thezapper'
     };

**RETURN VALUE**:

Return value is exactly the same as with ["find($params)"](#find-params)

## $WWW::Mechanize::Chrome::DOMops::VERBOSE\_DOMops

Set this upon loading the module to `0, 1, 2, 3`
to adjust verbosity. `0` implies no verbosity.

# ELEMENT SELECTORS

`Element selectors` are how one selects HTML elements from the DOM.
There are 5 ways to select HTML elements: by class (`element-class`),
tag (`element-tag`), id (`element-id`), name (`element-name`)
or via a CSS selector (`element-cssselector`).

Multiple selectors can be specified
by combining the various selector types, above.
For example,
one can select by `element-class` and `element-tag` (and ...).
In this selection mode, the matched elements from each selector type
(e.g. set A contains the HTML elements matched via `element-class`
and set B contains the HTML elements matched via `element-tag`)
must be combined by means of either the UNION (`||`)
or INTERSECTION (`&&`) of the two sets A and B.

Each selector can take one or more values. If you want to select
by just one class then provide that one class as a string scalar.
If you want to select an HTML elements which may belong to two classes,
then provide the two class names as an array.

These are the valid selectors:

- `element-class` : find DOM elements matching this class name
- `element-tag` : find DOM elements matching this element tag
- `element-id` : find DOM element matching this element id
- `element-name` : find DOM element matching this element name
- `element-cssselector` : find DOM element matching this CSS selector

And one of these two must be used to combine the results
into a final list:

- `&&` : Intersection. When set to 1 the result is the intersection of all individual results.
Meaning that an element will make it to the final list if it was matched
by every selector specified. This is the default.
- `||` : Union. When set to 1 the result is the union of all individual results.
Meaning that an element will make it to the final list if it was matched
by at least one of the selectors specified.

    As an example, the following selects all HTML elements which belong to class X AND class Y.
    It also selects all HTML elements of the `div` tag. And calculates
    the union of the two sets:

        {
          'element-class' => ['X', 'Y'],
          'element-tag' => 'div',
          '&&' => 1,
        }

# CREATING THE MECH OBJECT

The mech ([WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome)) object must be supplied
to the functions in this module. It must be created by the caller.
This is how I do it:

    use WWW::Mechanize::Chrome;
    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($ERROR);

    my %default_mech_params = (
        headless => 1,
    #   log => $mylogger,
        launch_arg => [
                '--window-size=600x800',
                '--password-store=basic', # do not ask me for stupid chrome account password
    #           '--remote-debugging-port=9223',
    #           '--enable-logging', # see also log above
                '--disable-gpu',
                '--no-sandbox',
                '--ignore-certificate-errors',
                '--disable-background-networking',
                '--disable-client-side-phishing-detection',
                '--disable-component-update',
                '--disable-hang-monitor',
                '--disable-save-password-bubble',
                '--disable-default-apps',
                '--disable-infobars',
                '--disable-popup-blocking',
        ],
    );

    my $mech_obj = eval {
        WWW::Mechanize::Chrome->new(%default_mech_params)
    };
    die $@ if $@;

    # This transfers all javascript code's console.log(...)
    # messages to perl's warn()
    # we need to keep $console var in scope!
    my $console = $mech_obj->add_listener('Runtime.consoleAPICalled', sub {
          warn
              "js console: "
            . join ", ",
              map { $_->{value} // $_->{description} }
              @{ $_[0]->{params}->{args} };
        })
    ;

    # and now fetch a page
    my $URL = '...';
    my $retmech = $mech_obj->get($URL);
    die "failed to fetch $URL" unless defined $retmech;
    $mech_obj->sleep(1); # let it settle
    # now the mech object has loaded the URL and has a DOM hopefully.
    # You can pass it on to find() or zap() to operate on the DOM.

# SECURITY WARNING

[WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome) invokes the `google-chrome`
executable
on behalf of the current user. Headless or not, `google-chrome`
is invoked. Depending on the launch parameters, either
a fresh, new browser session will be created or the
session of the current user with their profile, data, cookies,
passwords, history, etc. will be used. The latter case is very
dangerous.

This behaviour is controlled by [WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome)'s
[constructor](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%23WWW%3A%3AMechanize%3A%3AChrome-%253Enew%28-%25options-%29)
parameters which, in turn, are used for launching
the `google-chrome` executable. Specifically,
see [WWW::Mechanize::Chrome#separate\_session](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%23separate_session),
[<WWW::Mechanize::Chrome#data\_directory](https://metacpan.org/pod/%3CWWW%3A%3AMechanize%3A%3AChrome%23data_directory)
and [WWW::Mechanize::Chrome#incognito](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%23incognito).

**Unless you really need to mechsurf with your current session, aim
to launching the browser with a fresh new session.
This is the safest option.**

**Do not rely on default behaviour as this may change over
time. Be explicit.**

Also, be warned that [WWW::Mechanize::Chrome::DOMops](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%3A%3ADOMops) executes
javascript code on that `google-chrome` instance.
This is done nternally with javascript code hardcoded
into the [WWW::Mechanize::Chrome::DOMops](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%3A%3ADOMops)'s package files.

On top of that [WWW::Mechanize::Chrome::DOMops](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%3A%3ADOMops) allows
for **user-specified javascript code** to be executed on
that `google-chrome` instance. For example the callbacks
on each element found, etc.

This is an example of what can go wrong if
you are not using a fresh `google-chrome`
session:

You have just used `google-chrome` to access your
yahoo webmail and you did not logout.
So, there will be an
access cookie in the `google-chrome` when you later
invoke it via [WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome) (remember
you have not told it to use a fresh session).

If you allow
unchecked user-specified (or copy-pasted from ChatGPT)
javascript code in
[WWW::Mechanize::Chrome::DOMops](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%3A%3ADOMops)'s
`find()`, `zap()`, etc. then it is, theoretically,
possible that this javascript code
initiates an XHR to yahoo and fetch your emails and
pass them on to your perl code.

But there is another problem,
[WWW::Mechanize::Chrome::DOMops](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%3A%3ADOMops)'s
integrity of the embedded javascript code may have
been compromised to exploit your current session.

This is very likely with a Windows installation which,
being the security swiss cheese it is, it
is possible for anyone to compromise your module's code.
It is less likely in Linux, if your modules are
installed by root and are read-only for normal users.
But, still, it is possible to be compromised (by root).

Another issue is with the saved passwords and
the browser's auto-fill when landing on a login form.

Therefore, for all these reasons, **it is advised not to invoke (via [WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome))
`google-chrome` with your
current/usual/everyday/email-access/bank-access
identity so that it does not have access to
your cookies, passwords, history etc.**

It is better to create a fresh
`google-chrome`
identity/profile and use that for your
`WWW::Mechanize::Chrome::DOMops` needs.

No matter what identity you use, you may want
to erase the cookies and history of `google-chrome`
upon its exit. That's a good practice.

It is also advised to review the
javascript code you provide
via [WWW::Mechanize::Chrome::DOMops](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%3A%3ADOMops) callbacks if
it is taken from 3rd-party, human or not, e.g. ChatGPT.

Additionally, make sure that the current
installation of [WWW::Mechanize::Chrome::DOMops](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%3A%3ADOMops)
in your system is not compromised with malicious javascript
code injected into it. For this you can check its MD5 hash.

# DEPENDENCIES

This module depends on [WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome) which, in turn,
depends on the `google-chrome` executable be installed on the
host computer. See [WWW::Mechanize::Chrome::Install](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome%3A%3AInstall) on
how to install the executable.

Test scripts (which create there own mech object) will detect the absence
of `google-chrome` binary and exit gracefully, meaning the test passes.
But with a STDERR message to the user. Who will hopefully notice it and
proceed to `google-chrome` installation. In any event, this module
will be installed with or without `google-chrome`.

# AUTHOR

Andreas Hadjiprocopis, `<bliako at cpan.org>`

# CODING CONDITIONS

This code was written under extreme climate conditions of 44 Celsius.
Keep packaging those
vegs in kilos of plastic wrappers, keep obsolidating our perfectly good
hardware, keep inventing new consumer needs and brainwash them
down our throats, in short **Crack Deep the Roof Beam, Capitalism**.

# BUGS

Please report any bugs or feature requests to `bug-www-mechanize-chrome-domops at rt.cpan.org`, or through
the web interface at [https://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Mechanize-Chrome-DOMops](https://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Mechanize-Chrome-DOMops).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Mechanize::Chrome::DOMops

You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

    [https://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Mechanize-Chrome-DOMops](https://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Mechanize-Chrome-DOMops)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/WWW-Mechanize-Chrome-DOMops](http://annocpan.org/dist/WWW-Mechanize-Chrome-DOMops)

- Review this module at PerlMonks

    [https://www.perlmonks.org/?node\_id=21144](https://www.perlmonks.org/?node_id=21144)

- Search CPAN

    [https://metacpan.org/release/WWW-Mechanize-Chrome-DOMops](https://metacpan.org/release/WWW-Mechanize-Chrome-DOMops)

# DEDICATIONS

Almaz

# ACKNOWLEDGEMENTS

[CORION](https://metacpan.org/pod/CORION) for publishing  [WWW::Mechanize::Chrome](https://metacpan.org/pod/WWW%3A%3AMechanize%3A%3AChrome) and all its
contributors.

# LICENSE AND COPYRIGHT

Copyright 2019 Andreas Hadjiprocopis.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

[http://www.perlfoundation.org/artistic\_license\_2\_0](http://www.perlfoundation.org/artistic_license_2_0)

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
