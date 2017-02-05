--------------------------------------------------------------------------
-- The SitePackage customization for UGent-HPC
-- Ward Poelmans <ward.poelmans@ugent.be>
-- Kenneth Hoste <kenneth.hoste@ugent.be>
--------------------------------------------------------------------------

require("strict")
require("cmdfuncs")
require("utils")
require("lmod_system_execute")
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

    local frameStk = FrameStk:singleton()
    -- yes means that it is a module directly request by the user
    local userload = (frameStk:atTop()) and "yes" or "no"

    local logTbl      = {}
    logTbl[#logTbl+1] = {"userload", userload}
    logTbl[#logTbl+1] = {"module", t.modFullName}
    logTbl[#logTbl+1] = {"fn", t.fn}

    logmsg(logTbl)
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
    dbg.start{"startup_hook"}

    -- masterTbl has all info about the arguments passed to Lmod
    local masterTbl = masterTbl()

    dbg.print{"Received usrCmd: ", usrCmd, "\n"}
    dbg.print{"masterTbl:", masterTbl, "\n"}

    local fullargs = table.concat(masterTbl.pargs, " ") or ""
    local logTbl = {}
    logTbl[#logTbl+1]= {"cmd", usrCmd}
    logTbl[#logTbl+1]= {"args", fullargs}

    logmsg(logTbl)

    if usrCmd == "load" and (fullargs == "cluster" or fullargs == "cluster/")
        and os.getenv("VSC_INSTITUTE_CLUSTER") then

        LmodWarning([['module load cluster' has no effect when a 'cluster' module is already loaded.
        For more information, please see https://www.vscentrum.be/cluster-doc/software/modules/lmod#module_load_cluster]])

        os.exit(0)
    end

    local env_vars = {"LD_LIBRARY_PATH", "LD_PRELOAD"}

    for _, var in ipairs(env_vars) do
        local orig_val = os.getenv("ORIG_" .. var) or ""
        if orig_val ~= "" then
            dbg.print{"Setting ", var, " to ", orig_val, "\n"}
            posix.setenv(var, orig_val)
        end
    end

    dbg.fini()
end


local function errwarnmsg_hook(kind, key, msg, t)
    -- kind is either lmoderror, lmodwarning or lmodmessage
    -- msg is the actual message to display (as string)
    -- key is a unique key for the message (see messageT.lua)
    -- t is a table with the keys used in msg
    dbg.start{"errwarnmsg_hook"}

    dbg.print{"kind: ", kind}
    dbg.print{"Msg: ", msg}
    dbg.print{"keys: ", t}

    if key == "e_No_AutoSwap" then
        -- find the module name causing the issue (almost always toolchain module)
        local sname = t.sn
        local frameStk = FrameStk:singleton()

        local errmsg = {"A different version of the '"..sname.."' module is already loaded (see output of 'ml')."}
        if not frameStk:empty() then
            errmsg[#errmsg+1] = "You should load another '"..frameStk:sn().."' module for that is compatible with the currently loaded version of '"..sname.."'."
            errmsg[#errmsg+1] = "Use 'ml spider "..frameStk:sn().."' to get an overview of the available versions."
        end
        errmsg[#errmsg+1] = "\n"

        msg = table.concat(errmsg, "\n")
    end

    if kind == "lmoderror" or kind == "lmodwarning" then
        msg = msg .. "\nIf you don't understand the warning or error, contact the helpdesk at hpc@ugent.be"
    end

    dbg.fini()

    return msg
end


local function msg_hook(mode, output)
    -- mode is avail, list or spider
    -- output is a table with the current output

    dbg.start{"msg_hook"}

    dbg.print{"Mode is ", mode, "\n"}

    if mode == "avail" then
        output[#output+1] = "\nIf you need software that is not listed, request it at hpc@ugent.be\n"
    end

    dbg.fini()

    return output
end


local function site_name_hook()
    -- set the SiteName
    return "HPCUGENT"
end


local function packagebasename(t)
    -- Use the EBROOT variables in the module
    -- as base dir for the reverse map
    t.patDir = "^EBROOT.*"
end


hook.register("load", load_hook)
-- Needs more testing before enabling:
-- hook.register("restore", restore_hook)
hook.register("startup", startup_hook)
hook.register("msgHook", msg_hook)
hook.register("SiteName", site_name_hook)
hook.register("packagebasename", packagebasename)
hook.register("errWarnMsgHook", errwarnmsg_hook)
