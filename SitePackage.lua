--------------------------------------------------------------------------
-- The SitePackage customization for UGent-HPC & VUB-HPC
-- Ward Poelmans <ward.poelmans@ugent.be>
-- Kenneth Hoste <kenneth.hoste@ugent.be>
-- Ward Poelmans <ward.poelmans@vub.ac.be>
--------------------------------------------------------------------------

require("strict")
require("cmdfuncs")
require("utils")
require("lmod_system_execute")
require("parseVersion")
local Dbg   = require("Dbg")
local dbg   = Dbg:dbg()
local hook  = require("Hook")
local posix = require("posix")
local FrameStk  = require("FrameStk")


local function logmsg(logTbl)
    -- Print to syslog with generic header
    -- All the elements in the table logTbl are
    -- added in order. Expect format:
    -- logTbl[#logTbl+1] = {'log_key', 'log_value'}

    local cluster = os.getenv("VSC_INSTITUTE_CLUSTER") or ""
    local jobid = os.getenv("PBS_JOBID") or ""
    local user = os.getenv("USER")

    local msg = string.format("username=%s, cluster=%s, jobid=%s",
                              user, cluster, jobid)

    for _, val in ipairs(logTbl) do
        msg = msg .. string.format(", %s=%s", val[1], val[2] or "")
    end

    lmod_system_execute("/bin/logger -t lmod -p user.notice -- " .. msg)
end


local function load_hook(t)
    -- Called every time a module is loaded
    -- the arg t is a table:
    --     t.modFullName:  the module full name: (i.e: gcc/4.7.2)
    --     t.fn:           the file name: (i.e /apps/modulefiles/Core/gcc/4.7.2.lua)

    -- unclear whether this is needed (and rtmclay agrees), but no harm in keeping it
    if (mode() ~= "load") then return end

    -- if userload is yes, the user request to load this module. Else
    -- it is getting loaded as a dependency.
    local frameStk = FrameStk:singleton()
    -- yes means that it is a module directly request by the user
    local userload = (frameStk:atTop()) and "yes" or "no"

    local logTbl      = {}
    logTbl[#logTbl+1] = {"userload", userload}
    logTbl[#logTbl+1] = {"module", t.modFullName}
    logTbl[#logTbl+1] = {"fn", t.fn}

    -- Don't log any modules load by the monitoring
    if os.getenv("USER") ~= "zabbix" then
        logmsg(logTbl)
    end

    -- warn users about old modules (only directly loaded ones)
    if os.getenv("VSC_OS_LOCAL") == "CO7" and frameStk:atTop() then
        local arch, toolchainver
        arch, toolchainver = t.fn:match("^/apps/brussel/CO7/(.+)/modules/(20[12][0-9][ab])/all/")

        if toolchainver == nil then return end

	local cutoff = string.format("%da", os.date("%Y") - 2)

        if parseVersion(toolchainver) < parseVersion(cutoff) then
	    LmodWarning{msg="sisc_deprecated_module", fullName=t.modFullName, tcver_cutoff=cutoff}
        end
    end
end

--[[
local function restore_hook(t)
    -- This hook is called after a restore operation
    -- the arg t is a table:
    --     t.collection: the input name of the collection
    --     t.name:       the output name of the collection
    --     t.fn:         The file name: (i.e /apps/modulefiles/Core/gcc/4.7.2.lua)

    dbg.start{"restore_hook"}

    local cluster = os.getenv("VSC_INSTITUTE_CLUSTER")
    local def_cluster = os.getenv("VSC_DEFAULT_CLUSTER_MODULE")
    if (not cluster or not def_cluster) then return end

    if (cluster == def_cluster) then return end

    dbg.print{"Have: ", cluster, " Switch to ", def_cluster}

    Swap("cluster/" .. cluster, "cluster/" .. def_cluster)

    dbg.fini()
end
]]--

local function startup_hook(usrCmd)
    -- This hook is called right after starting Lmod
    -- usrCmd holds the currect active command
    -- if you want access to all give arguments, use
    -- masterTbl
    dbg.start{"startup_hook"}

    -- masterTbl has all info about the arguments passed to Lmod
    local masterTbl = masterTbl()

    dbg.print{"Received usrCmd: ", usrCmd, "\n"}
    dbg.print{"masterTbl:", masterTbl, "\n"}

    -- Log how Lmod was called
    local fullargs    = table.concat(masterTbl.pargs, " ") or ""
    local logTbl      = {}
    logTbl[#logTbl+1] = {"cmd", usrCmd}
    logTbl[#logTbl+1] = {"args", fullargs}

    logmsg(logTbl)

    dbg.fini()
end

local function msg_hook(mode, output)
    -- mode is avail, list and spider
    -- output is a table with the current output

    dbg.start{"msg_hook"}

    dbg.print{"Mode is ", mode, "\n"}

    if mode == "avail" then
        output[#output+1] = "\nIf you need software that is not listed, request it at hpc@vub.ac.be\n"
    end

    dbg.fini()

    return output
end

-- This gets called on every message, warning and error
local function errwarnmsg_hook(kind, key, msg, t)
    -- kind is either lmoderror, lmodwarning or lmodmessage
    -- key is a unique key for the message (see messageT.lua)
    -- msg is the actual message to display (as string)
    -- t is a table with the keys used in msg
    dbg.start{"errwarnmsg_hook"}

--    dbg.print{"kind: ", kind," key: ",key,"\n"}
--    dbg.print{"keys: ", t}

    if key == "e_No_AutoSwap" then
        -- Customize this error for EasyBuild modules
        -- When the users gets this error, it mostly likely means
        -- that they are trying to load modules belonging to different version of the same toolchain
        --
        -- find the module name causing the issue (almost always toolchain module)
        local sname = t.sn
        local frameStk = FrameStk:singleton()

        local errmsg = {"A different version of the '"..sname.."' module is already loaded (see output of 'ml')."}
        if not frameStk:empty() then
            local framesn = frameStk:sn()
            errmsg[#errmsg+1] = "You should load another '"..framesn.."' module for that is compatible with the currently loaded version of '"..sname.."'."
            errmsg[#errmsg+1] = "Use 'ml spider "..framesn.."' to get an overview of the available versions."
        end
        errmsg[#errmsg+1] = "\n"

        msg = table.concat(errmsg, "\n")
    end

    if kind == "lmoderror" or kind == "lmodwarning" then
        msg = msg .. "\nIf you don't understand the warning or error, contact the helpdesk at hpc@vub.ac.be"
    end

    -- log any errors users get
    if kind == "lmoderror" then
        local logTbl      = {}
        logTbl[#logTbl+1] = {"error", key}

        for tkey, tval in pairs(t) do
            logTbl[#logTbl+1] = {tkey, tval}
        end

        logmsg(logTbl)
    end

    dbg.fini()

    return msg
end


local function site_name_hook()
    -- set the SiteName, it must be a valid
    -- shell variable name.
    return "HPC-SISC"
end


-- To combine EasyBuild with XALT
local function packagebasename(t)
    -- Use the EBROOT variables in the module
    -- as base dir for the reverse map
    t.patDir = "^EBROOT.*"
end


local function visible_hook(modT)
    -- modT is a table with: fullName, sn, fn and isVisible
    -- The latter is a boolean to determine if a module is visible or not

    local tcver = modT.fn:match("^/apps/brussel/.*/modules/(20[0-9][0-9][ab])/all/")
    if tcver == nil then return end

    -- always the the a version of two years ago
    local cutoff = string.format("%da", os.date("%Y") - 2)
    if parseVersion(tcver) < parseVersion(cutoff) then
        modT.isVisible = false
    end
end

hook.register("load", load_hook)
-- Needs more testing before enabling:
-- hook.register("restore", restore_hook)
hook.register("startup", startup_hook)
hook.register("msgHook", msg_hook)
hook.register("SiteName", site_name_hook)
hook.register("packagebasename", packagebasename)
hook.register("errWarnMsgHook", errwarnmsg_hook)
hook.register("isVisibleHook", visible_hook)
