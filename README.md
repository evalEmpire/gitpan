What is Gitpan?
---------------

Gitpan is a project to import the entire history of CPAN (known as
BackPAN) into a set of git repositories, one per distribution.


What is CPAN?
-------------

CPAN is the Comprehensive Perl Archive Network at cpan.org.  It is an
archive of tens of thousands of Perl modules written by thousands of
authors.  A good interface to it is http://metacpan.org


What is BackPAN?
----------------

In order to limit CPAN's size, authors are requested to delete old
releases.  BackPAN maintains all CPAN releases, even deleted ones, and
is a complete history of CPAN.  There are only a few BackPAN mirrors
such as http://backpan.perl.org


Why is Gitpan?
--------------

CPAN (and thus BackPAN) is a pile of tarballs organized by author.  It
is difficult to get the complete history of a distribution, especially
one that has changed authors or is released by multiple authors (for
example, Moose).  Because releases are regularly deleted from CPAN
even sites like search.cpan.org provide an incomplete history.  Having
the complete history of each distrubtion in its own repository makes
the full distribution history easy to access.

Gitpan also hopes to make patching CPAN modules easier.  Ideally you
simply clone the Gitpan repository and work.  New releases can be
pulled and merged from Gitpan.

Gitpan hopes to showcase using a repository as an archive format,
rather than a pile of tarballs.  A repository is far more useful than
a pile of tarballs, and contrary to many people's expectations, the
repository is turning out smaller.

Finally, Gitpan is being created in the hope that "if you build it
they will come".  Getting data out of CPAN in an automated fashion has
traditionally been difficult.


Where is Gitpan?
----------------

The repositories are on github.com at http://github.com/gitpan.

Code, discussion, and issues can be had at http://github.com/evalEmpire/gitpan.


How do I access a distribution on Gitpan?
-----------------------------------------

Simplest way is to go to http://github.com/gitpan/<distribution>.
For example, Acme-Pony can be found at http://github.com/gitpan/Acme-Pony.
Instructions for futher access can be found there.

The clone URL for a given distribution is git://github.com/gitpan/<distribution>.git.
You can clone without a github account.


How big is BackPAN?
-------------------

BackPAN (just the modules, we're not doing perl releases) contains
over 230,000 archive files (mostly gzipped tarballs) representing over
35,000 distributions from over 6500 authors taking over 38 gigs of space.


How big is Gitpan?
------------------

Gitpan consists of over 35,000 repositories representing each CPAN
distribution.  Disk usage (garbage collected repositories with the
latest version checked out checkout) is about 30 gigs.  It imported
over 230,000 releases with a compressed size of over 33 gigs.


Did Gitpan skip anything?
-------------------------

Yes.  Gitpan generally skips things which are not modules, such as
scripts, binary releases, patches, documentation and other randomness
which has been uploaded to CPAN over the years.  Gitpan also skips
releases of Perl and Parrot, they are large and there are plenty of
better archives for that.

Github has a limit of 100 megs per file, so Gitpan cannot archive the
few files which go over that limit and will instead replace it with a
dummy file indicating why it was skipped.

Gitpan skips any archives which cannot be extracted.  Sometimes they
are corrupt beyond repair, sometimes they can be extracted with some
manual effort.

Occassionally something which is not a module will be considered of
sufficient historical interest that it will be included, such as a
heavily patched version of Perl for an obscure operating system, or a
set of very old, well developed scripts.


Will you be adding X to Gitpan?
-------------------------------

The primary focus is to get accurate repositories for each CPAN
distribution and to make this data available for others to use.  When
you think "will Gitpan do X" instead think "how can I use Gitpan to
build X?"

Suggestions on how to improve the data available from Gitpan heartily
accepted.


How can I merge Gitpan's history with my module?
------------------------------------------------

If you are the owner of a CPAN module and have an existing, but
incomplete, repository you can fill in the history using Gitpan.  The
technique is outlined in this article.
http://use.perl.org/~schwern/journal/39974


How do I update my module on Gitpan?
------------------------------------

Gitpan will automatically pull new releases from CPAN, you don't have
to do anything.


When does Gitpan update?
-

Updates happen about once a week.  We hope to make them daily.


Where can I get a list of all the repositories?
-----------------------------------------------

You can get it from [Github's API](http://developer.github.com) by
[listing all of Gitpan's
repositories](https://developer.github.com/v3/repos/#list-organization-repositories).  The list is rather large and will require multiple calls.  See [Pagination](https://developer.github.com/v3/#pagination).


How can I help?
---------------

See http://github.com/evalEmpire/gitpan/issues for a list of open problems.

You can also contribute by looking through imported CPAN distributions,
checking for mistakes and reporting them as issues.


I'm the author of X distribution and already have a repository, would you delete the Gitpan repo?
----------

Sorry, no.

Gitpan is intended to co-exist with, not compete with, the development
repository for a distribution.  It provides a consistent, easy to find
interface to your releases so you don't have to.

Gitpan serves purposes different from the development repo.  A Gitpan
repo...

* Has a consistent location.
* Has a consistent structure.
* Uses a consistent version control system.
* Is only for releases.
* Has the entire release history.

While there are many different ways to use Gitpan, the primary use is
to examine the release history of any given distribution regardless of
the preferences of the distribution authors.

Gitpan tries to make it as clear as possible that it is not a
development repository (descriptive text, descriptive commits, no
issue tracker, no wiki) and to point the user at the proper
development resources (ie. the distribution's Metacpan page).

You can make your own development repository more visible by adding a
repository resource to your release meta-data.  See
https://metacpan.org/pod/CPAN::Meta::Spec#resources


I'm the author of X distribution, can I get commit access to Gitpan?
--------------------------------------------------------------------

Sorry, no.  Gitpan is intentionally read-only to provide a consistent
interface over all of CPAN.  Allowing developers to commit directly to
Gitpan would endanger this consistency.  In this sense, Gitpan is
simply a read-only view on your releases.

As the developer of the project, you should continue to develop
against your regular repo.  However, it is helpful to fill in back
history should you be missing it.  You can use the release tags and
dates on the Gitpan repo to place tags into your development repo.  If
history is completely missing, you can splice your development
repository on top of the Gitpan repo.  See "How can I merge Gitpan's
history with my module?" above.

You could develop off a Gitpan fork, but the actual development
history of your project up to this point would be lost.  Merging your
dev repo with Gitpan is left as an exercise for the reader to do
usefully.  If you tag your releases in a consistent manner and publish
the location of your repository, Gitpan doesn't offer anything new to
the developer.


I found a distribution that's out of date, could you update it?
--

If it's less than a week old, wait another week and it will probably
happen as part of the normal update process.

If it's more than a week old, please report it to us at
<http://github.com/evalEmpire/gitpan/issues> or
schwern+gitpan@pobox.com.


I noticed a problem with a repository
-------------------------------------

Please report it at <http://github.com/evalEmpire/gitpan/issues> or to
schwern+gitpan@pobox.com.


Who do we have to thank for Gitpan?
-----------------------------------

Gitpan exists on top of a pile of pre-existing technology and services.
Very little new code was written and the yaks were already well shorn.

* Elaine Ashton for instituting BackPAN.
* Jarkko, Graham Barr and the rest of the CPAN cabal.
* Andreas König for tirelessly maintaining PAUSE.
* brian d foy for spearheading BackPAN archeology.
* Léon Brocard for Parse::BACKPAN::Packages to access the backpan index and maintaining the BackPAN index.
* Linus and the git devs for git (this was tried before on SVN and guh...)
* github.com for a generous donation of space and support and angry unicorns
* Integra Telecom for donating a server.
* Yanick Champoux for git-cpan-patch which does most of the work.
* ftp.funet.fi for an rsync-able BackPAN mirror.
* Michael Schwern glued it all together.
* And all the people who [contributed code](https://github.com/evalEmpire/gitpan/graphs/contributors) and [reported issues](https://github.com/evalEmpire/gitpan/issues?q=is%3Aissue+is%3Aclosed).


How can I contact Gitpan?
-------------------------

* Email:   schwern+gitpan@pobox.com
* Web:     http://github.com/gitpan/
* Dev:     http://github.com/evalEmpire/gitpan
* Issues:  http://github.com/evalEmpire/gitpan/issues
* Twitter: #gitpan and http://twitter.com/gitpan
