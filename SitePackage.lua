--------------------------------------------------------------------------
-- Lmod License
--------------------------------------------------------------------------
--
--  Lmod is licensed under the terms of the MIT license reproduced below.
--  This means that Lmod is free software and can be used for both academic
--  and commercial purposes at absolutely no cost.
--
--  ----------------------------------------------------------------------
--
--  Copyright (C) 2008-2014 Robert McLay
--
--  Permission is hereby granted, free of charge, to any person obtaining
--  a copy of this software and associated documentation files (the
--  "Software"), to deal in the Software without restriction, including
--  without limitation the rights to use, copy, modify, merge, publish,
--  distribute, sublicense, and/or sell copies of the Software, and to
--  permit persons to whom the Software is furnished to do so, subject
--  to the following conditions:
--
--  The above copyright notice and this permission notice shall be
--  included in all copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
--  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--  NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
--  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
--  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
--  THE SOFTWARE.
--
--------------------------------------------------------------------------

require("strict")
require("cmdfuncs")
local Dbg  = require("Dbg")
local dbg  = Dbg:dbg()
local hook = require("Hook")


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

hook.register("load", load_hook)
-- hook.register("restore", restore_hook)
