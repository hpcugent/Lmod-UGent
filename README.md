Lmod for HPC-UGent
==================

This repo contains the spec for Lmod used at HPC-UGent. It's a fork
from the Fedora upstream spec file. We use our own set of configure
options and we don't allow environment-modules to coexist with Lmod.

Our configure options
---------------------
- `caseIndependentSorting=yes`:
  Make avail and spider use case independent sorting

- `redirect=yes`:
  Output to stdout instead stderr

- `autoSwap=no`, `disableNameAutoSwap=yes`:
  We try to mimick the behaviour of environment-modules and don't
  let Lmod to it's swapping magic when changing cluster modules.
  We basically only want swapping when a module with the same name
  and version exists.

- `shortTime=86400`:
  Avoids that Lmod builds a user cache. The cache has a valid lifetime
  of 86400 (24h), and this tells Lmod not to write the cache to disk
  if it can be build in less then 24h.

- `pinVersions=yes`:
  Fix the version of packages saved in a collection. This avoids
  the need to rebuild the collection when the 'default' version
  of a package changes.

- `module-root-path=/etc/modulefiles/vsc`

- `cachedLoads=yes`:
  Use the cache to load modules. If the module is not in the cache, it
  cannot be loaded until the cache is rebuild. This avoids the costly
  stating of all directories when the module path is extend after
  loading a cluster module

Patches
-------

A (trivial) patch is applied to change the behaviour of 'module spider',
to adhere to a policy specific to HPC-UGent.

One or more hidden 'cluster' modules may be available for testing purposes.

These are not intended to be used for production however, and so 'module spider'
should not include these hidden cluster modules in the output.

Recent versions of Lmod do show hidden modules in the output of 'module spider' by default,
hence we patch our Lmod installation to behave otherwise.

SitePackage
-----------
The SitePackage contains a couple of hooks:
- A general function for logging
- The load hooks simply logs the loading of a module. It tells whether
  a module was loaded directly by a user or not.
- The restore hook is run after restoring a collection. We need to
  that the correct cluster module is loaded: If it's the same architecture
  and OS, collections from a different cluster can be used. However,
  as the cluster module is also saved as part of the collection, we
  need to swap in the right one.
- The startup hook is run on starting Lmod. It logs the commands run by
  the user and takes care of restoring the original `$LD_LIBRARY_PATH`.
- A message hook that points to user to the helpdesk when he/she gets a
  warning or error.
- The packagebasename hook lets Lmod use the EasyBuild root variable to
  generate the reverse map.
