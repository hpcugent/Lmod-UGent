#!/usr/bin/python -E
# -*- encoding: utf-8 -*-
#
# Copyright 2016-2016 Ghent University
#
# This file is part of Lmod-UGent,
# originally created by the HPC team of Ghent University (http://ugent.be/hpc/en),
# with support of Ghent University (http://ugent.be/hpc),
# the Flemish Supercomputer Centre (VSC) (https://www.vscentrum.be),
# the Flemish Research Foundation (FWO) (http://www.fwo.be/en)
# and the Department of Economy, Science and Innovation (EWI) (http://www.ewi-vlaanderen.be/en).
#
"""
This script runs the Lmod cache creation script and reports to nagios/icinga the exit status.
It also can check if the age of the current age and will report if it's too old.

@author: Ward Poelmans (Ghent University)
"""
import json
import os
import sys
import time
from vsc.utils import fancylogger
from vsc.utils.nagios import NAGIOS_EXIT_CRITICAL, NAGIOS_EXIT_WARNING
from vsc.utils.run import run_simple
from vsc.utils.script_tools import ExtendedSimpleOption

# log setup
logger = fancylogger.getLogger(__name__)
fancylogger.logToScreen(True)
fancylogger.setLogLevelInfo()

NAGIOS_CHECK_INTERVAL_THRESHOLD = 2 * 60 * 60  # 2 hours

def run_cache_create(modules_root):
    """Run the script to create the Lmod cache"""
    lmod_dir = os.environ.get("LMOD_DIR", None)
    if not lmod_dir:
        raise RuntimeError("Cannot find $LMOD_DIR in the environment.")

    cmd = "%s/update_lmod_system_cache_files %s" % (lmod_dir, modules_root)
    return run_simple(cmd)


def get_lmod_config():
    """Get the modules root and cache path from the Lmod config"""
    lmod_cmd = os.environ.get("LMOD_CMD", None)
    if not lmod_cmd:
        raise RuntimeError("Cannot find $LMOD_CMD in the environment.")

    ec, out = run_simple("%s bash --config-json" % lmod_cmd)
    if ec != 0:
        raise RuntimeError("Failed to get Lmod configuration: %s", out)

    try:
        lmodconfig = json.loads(out)

        config = {
            'modules_root': lmodconfig['configT']['mpath_root'],
            'cache_dir': lmodconfig['cache'][0][0],
            'cache_timestamp': lmodconfig['cache'][0][1],
        }
        logger.debug("Found Lmod config: %s", config)
    except (ValueError, KeyError, IndexError, TypeError) as err:
        raise RuntimeError("Failed to parse the Lmod configuration: %s", err)

    return config


def main():
    """
    Set the options and initiates the main run.
    Returns the errors if any in a nagios/icinga friendly way.
    """
    options = {
        'nagios-check-interval-threshold': NAGIOS_CHECK_INTERVAL_THRESHOLD,
        'create-cache': ('Create the Lmod cache', None, 'store_true', False),
        'freshness-threshold': ('The interval in minutes for how long we consider the cache to be fresh',
                                'int', 'store', 120),
    }
    opts = ExtendedSimpleOption(options)

    try:
        config = get_lmod_config()

        if opts.options.create_cache:
            opts.log.info("Updating the Lmod cache")
            exitcode, msg = run_cache_create(config['modules_root'])
            if exitcode != 0:
                logger.error("Lmod cache update failed: %s", msg)
                opts.critical("Lmod cache update failed")
                sys.exit(NAGIOS_EXIT_CRITICAL)

        opts.log.info("Checking the Lmod cache freshness")
        timestamp = os.stat(config['cache_timestamp'])

        # give a warning when the cache is older then --freshness-threshold
        if (time.time() - timestamp.st_mtime) > opts.options.freshness_threshold * 60:
            errmsg = "Lmod cache is not fresh"
            logger.warn(errmsg)
            opts.warning(errmsg)
            sys.exit(NAGIOS_EXIT_WARNING)

    except RuntimeError as err:
        logger.exception("Failed to update Lmod cache: %s", err)
        opts.critical("Failed to update Lmod cache. See logs.")
        sys.exit(NAGIOS_EXIT_CRITICAL)
    except Exception as err:  # pylint: disable=W0703
        logger.exception("critical exception caught: %s", err)
        opts.critical("Script failed because of uncaught exception. See logs.")
        sys.exit(NAGIOS_EXIT_CRITICAL)

    if opts.options.create_cache:
        opts.epilogue("Lmod cache updated.")
    else:
        opts.epilogue("Lmod cache is still fresh.")


if __name__ == '__main__':
    main()
