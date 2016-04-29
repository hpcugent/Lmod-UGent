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


-- By using the hook.register function, this function "load_hook" is called
-- ever time a module is loaded with the file name and the module name.
local function load_hook(t)
   -- the arg t is a table:
   --     t.modFullName:  the module full name: (i.e: gcc/4.7.2)
   --     t.fn:           the file name: (i.e /apps/modulefiles/Core/gcc/4.7.2.lua)

   if (mode() ~= "load") then return end
   local user = os.getenv("USER")
   local jobid = os.getenv("PBS_JOBID") or ""
   local cluster = os.getenv("VSC_INSTITUTE_CLUSTER") or ""
   local arch = os.getenv("VSC_ARCH_LOCAL") or ""
   local msg = string.format("user=%s, cluster=%s, arch=%s, module=%s, fn=%s, jobid=%s",
                             user, cluster, arch, t.modFullName, t.fn, jobid)
   os.execute("logger -t lmod -p user.notice " .. msg)
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
   -- local masterTbl = masterTbl()

   dbg.start{"startup_hook"}

   dbg.print{"Received usrCmd: ", usrCmd, "\n"}
   local ld_library_path = os.getenv("ORIG_LD_LIBRARY_PATH") or ""
   dbg.print{"Setting LD_LIBRARY_PATH to ", ld_library_path, "\n"}
   posix.setenv("LD_LIBRARY_PATH", ld_library_path)

   dbg.fini()
end

hook.register("load", load_hook)
hook.register("restore", restore_hook)
hook.register("startup", startup_hook)
