Lmod for HPC-UGent
==================

This repo contains the spec for Lmod used at HPC-UGent. It's a for
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
We add one patch to clear the `$LD_LIBRARY_PATH` before any lmod command is
executed. This makes sure that Lmod keeps on working, no matter what
modules are loaded. The original value of `$LD_LIBRARY_PATH` is saved to
`$ORIG_LD_LIBRARY_PATH` and the startup hook (see below) will restore it
when lua is already running. In this way, a new load will append to the correct
value of `$LD_LIBRARY_PATH` and lua keeps on workings if other modules are loaded.

SitePackage
-----------
The SitePackage contains a couple of hooks:
- The load hooks simply logs the loading of a hook
- The restore hook is run after restoring a collection. We need to 
  that the correct cluster module is loaded: If it's the same architecture
  and OS, collections from a different cluster can be used. However,
  as the cluster module is also saved as part of the collection, we
  need to swap in the right one.
- The startup hook is run on starting Lmod. It logs the loads requested by
  the user and takes care of restoring the original `$LD_LIBRARY_PATH`.
