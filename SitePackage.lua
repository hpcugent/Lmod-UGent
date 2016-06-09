--------------------------------------------------------------------------
-- The SitePackage customization for UGent-HPC
-- Ward Poelmans <ward.poelmans@ugent.be>
--------------------------------------------------------------------------

require("strict")
require("cmdfuncs")
require("utils")
local Dbg   = require("Dbg")
local dbg   = Dbg:dbg()
local hook  = require("Hook")
local posix = require("posix")


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

    os.execute("logger -t lmod -p user.notice -- " .. msg)
end


-- By using the hook.register function, this function "load_hook" is called
-- ever time a module is loaded with the file name and the module name.
local function load_hook(t)
   -- the arg t is a table:
   --     t.modFullName:  the module full name: (i.e: gcc/4.7.2)
   --     t.fn:           the file name: (i.e /apps/modulefiles/Core/gcc/4.7.2.lua)

   if (mode() ~= "load") then return end

   local masterTbl = masterTbl()
   local userload = "no"

   -- Not the most elegant way of doing it but
   -- until better is found, it will do
   for _, val in ipairs(masterTbl.pargs) do
       if string.find(t.modFullName, val) then
           userload = "yes"
       end
   end

   local logTbl = {}
   logTbl[#logTbl+1]= {"userload", userload}
   logTbl[#logTbl+1]= {"module", t.modFullName}
   logTbl[#logTbl+1]= {"fn", t.fn}

   logmsg(logTbl)

end


-- This hook is called after a restore operation
local function restore_hook(t)
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


-- This hook is called right after starting Lmod
local function startup_hook(usrCmd)
    -- usrCmd holds the currect active command
   -- if you want access to all give arguments, use
   local masterTbl = masterTbl()

   dbg.start{"startup_hook"}

   dbg.print{"Received usrCmd: ", usrCmd, "\n"}

   local fullargs = table.concat(masterTbl.pargs, " ") or ""
   local logTbl = {}
   logTbl[#logTbl+1]= {"cmd", usrCmd}
   logTbl[#logTbl+1]= {"args", fullargs}

   logmsg(logTbl)

   if usrCmd == "load" and (fullargs == "cluster" or fullargs == "cluster/")
      and string.find(os.getenv("LOADEDMODULES") or "", "cluster/") then
       dbg.print{"Loading default cluster module when it's already loaded. Bailing out!"}
       os.exit(0)
   end


   local ld_library_path = os.getenv("ORIG_LD_LIBRARY_PATH") or ""
   if ld_library_path ~= "" then
       dbg.print{"Setting LD_LIBRARY_PATH to ", ld_library_path, "\n"}
       posix.setenv("LD_LIBRARY_PATH", ld_library_path)
   end

   dbg.fini()
end


local function msg_hook(mode, output)
    -- mode is avail, list, ...
    -- output is a table with the current output

   if mode == "avail" then
       output[#output+1] = "\nIf you need software that is not listed, request it at hpc@ugent.be\n"
   end

   return output
end

hook.register("load", load_hook)
hook.register("restore", restore_hook)
hook.register("startup", startup_hook)
hook.register("msgHook", msg_hook)
