#!/usr/bin/env python
# -*- encoding: utf-8 -*-
#
# Copyright 2016-2016 Ghent University
#
# This file is part of icinga-checks,
# originally created by the HPC team of Ghent University (http://ugent.be/hpc/en),
# with support of Ghent University (http://ugent.be/hpc),
# the Flemish Supercomputer Centre (VSC) (https://vscentrum.be/nl/en),
# the Flemish Research Foundation (FWO) (http://www.fwo.be/en)
# and the Department of Economy, Science and Innovation (EWI) (http://www.ewi-vlaanderen.be/en).
#
"""
This script runs the Lmod cache creation script and reports to nagios/icinga the exit status.
It also can check if the age of the current age and will report if it's too old.

@author: Ward Poelmans (Ghent University)
"""
import os
import sys
import time
from vsc.utils.script_tools import ExtendedSimpleOption
from vsc.utils import fancylogger
from vsc.utils.nagios import NAGIOS_EXIT_CRITICAL, NAGIOS_EXIT_WARNING
from vsc.utils.run import run_simple

# log setup
logger = fancylogger.getLogger(__name__)
fancylogger.logToScreen(True)
fancylogger.setLogLevelInfo()


def run_cache_create():
    """Run the script to create the Lmod cache"""
    lmod_dir = os.environ.get("LMOD_DIR", None)
    if not lmod_dir:
        errmsg = "Cannot find $LMOD_DIR in the environment."
        logger.error(errmsg)
        return (1, errmsg)

    cmd = "%s/update_lmod_system_cache_files /etc/modulefiles/vsc" % lmod_dir
    return run_simple(cmd)


def main():
    """
    Set the options and initiates the main run.
    Returns the errors if any in a nagios/icinga friendly way.
    """
    options = {
        'create-cache': ('Create the Lmod cache', None, 'store_true', False),
    }
    opts = ExtendedSimpleOption(options)

    try:
        if opts.options.create_cache:
            opts.log.info("Updating the Lmod cache")
            exitcode, msg = run_cache_create()
            if exitcode != 0:
                errmsg = "Lmod cache update failed: %s" % msg
                logger.error(errmsg)
                opts.critical(errmsg)
                sys.exit(NAGIOS_EXIT_CRITICAL)

        opts.log.info("Checking the Lmod cache freshness")
        # until the json api from the Lmod config is ready, we hardcode the path
        LMOD_CACHE_TIMESTAMP = "/apps/gent/lmodcache/timestamp"
        timestamp = os.stat(LMOD_CACHE_TIMESTAMP)

        # give a warning when the cache is older then 2h
        if (time.time() - timestamp.st_mtime) > 2 * 3600:
            errmsg = "Lmod cache is not fresh"
            logger.warn(errmsg)
            opts.warning(errmsg)
            sys.exit(NAGIOS_EXIT_WARNING)

    except Exception, err:
        logger.exception("critical exception caught: %s" % (err))
        opts.critical("Script failed because of uncaught exception. See logs.")
        sys.exit(NAGIOS_EXIT_CRITICAL)

    if opts.options.create_cache:
        opts.epilogue("Lmod cache updated.")
    else:
        opts.epilogue("Lmod cache is still fresh.")


if __name__ == '__main__':
    main()
