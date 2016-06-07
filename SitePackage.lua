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

    local user = os.getenv("USER")
    local jobid = os.getenv("PBS_JOBID") or ""
    local cluster = os.getenv("VSC_INSTITUTE_CLUSTER") or ""
    local arch = os.getenv("VSC_ARCH_LOCAL") or ""

    local msg = string.format("username=%s, cluster=%s, arch=%s, jobid=%s",
                              user, cluster, arch, jobid)

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

   local logTbl = {}
   logTbl[#logTbl+1]= {"userload", "no"}  -- FIXME: should be yes on user requested load of the module (not loaded as a dep)
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

   local logTbl = {}
   logTbl[#logTbl+1]= {"cmd", usrCmd}
   logTbl[#logTbl+1]= {"args", table.concat(masterTbl.pargs, " ")}

   logmsg(logTbl)

   local ld_library_path = os.getenv("ORIG_LD_LIBRARY_PATH") or ""
   if ld_library_path ~= "" then
       dbg.print{"Setting LD_LIBRARY_PATH to ", ld_library_path, "\n"}
       posix.setenv("LD_LIBRARY_PATH", ld_library_path)
   end

   dbg.fini()
end

hook.register("load", load_hook)
hook.register("restore", restore_hook)
hook.register("startup", startup_hook)
