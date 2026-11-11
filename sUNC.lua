--[[
    sUNC - senS' Unified Naming Convention
    Clean reimplementation — unobfuscated, full coverage
    Categories: Closures, Debug, Drawing, Encoding, Environment,
                Filesystem, Instances, Metatable, Miscellaneous,
                Reflection, Scripts, Signals, WebSocket

    Usage:
        getgenv().sUNCDebug = {
            printcheckpoints    = false,
            delaybetweentests   = 0,
            printtesttimetaken  = false,
            -- optional: only run specific tests
            functionstotest = {
                -- ["cloneref"] = true,
                -- ["filesys"]  = true,
            },
        }
        loadstring(game:HttpGet("..."))()   -- or paste directly
]]

-- ───────────────────────────────────────────────────────────
--  Config
-- ───────────────────────────────────────────────────────────
local cfg = getgenv().sUNCDebug or {}
local DELAY          = cfg.delaybetweentests   or 0
local CHECKPOINTS    = cfg.printcheckpoints    or false
local PRINT_TIME     = cfg.printtesttimetaken  or false
local FILTER         = cfg.functionstotest     -- nil = run all

print([[ 

╔══════════════════════════════════════════════╗
║  sUNC · senS' Unified Naming Convention      ║
║  81 tests · 13 categories · unobfuscated     ║
╚══════════════════════════════════════════════╝
]])

-- ───────────────────────────────────────────────────────────
--  Result tracking
-- ───────────────────────────────────────────────────────────
local results = {
    passed   = 0,
    failed   = 0,
    untested = 0,
}

local function pass(name)
    results.passed += 1
    print(string.format("[sUNC] ✅ %s", name))
end

local function fail(name, reason)
    results.failed += 1
    warn(string.format("[sUNC] ❌ %s", name))
    if reason then
        warn(string.format("[sUNC]    └─ %s", tostring(reason)))
    end
end

local function untested(name)
    results.untested += 1
    print(string.format("[sUNC] ⬜ %s — not supported", name))
end

local function checkpoint(msg)
    if CHECKPOINTS then print("[sUNC][cp] " .. msg) end
end

local function banner(title)
    print("\n── " .. title .. " " .. string.rep("─", math.max(1, 44 - #title)))
end

-- ───────────────────────────────────────────────────────────
--  Test runner
-- ───────────────────────────────────────────────────────────
local function run(name, group, fn)
    -- filter: if functionstotest is set, skip unless name or group is listed
    if FILTER then
        local keep = FILTER[name] or (group and FILTER[group])
        if not keep then
            results.untested += 1
            return
        end
    end

    local t0 = os.clock()
    local ok, err = pcall(fn)
    local dt = os.clock() - t0

    if ok then
        if PRINT_TIME then
            print(string.format("[sUNC] ✅ %s (%.3fs)", name, dt))
        else
            pass(name)
        end
    else
        fail(name, err)
    end

    if DELAY > 0 then task.wait(DELAY) end
end

local function notSupported(name)
    if FILTER and not FILTER[name] then
        results.untested += 1
        return
    end
    untested(name)
end

-- ───────────────────────────────────────────────────────────
--  Helpers
-- ───────────────────────────────────────────────────────────
local function assert2(cond, msg)
    if not cond then error(msg or "assertion failed", 2) end
end

local function typecheck(val, expected, label)
    assert2(type(val) == expected,
        string.format("%s: expected %s, got %s", label or "?", expected, type(val)))
end

-- ───────────────────────────────────────────────────────────
--  CLOSURES
-- ───────────────────────────────────────────────────────────
banner("Closures")

run("iscclosure", "Closures", function()
    assert2(iscclosure ~= nil, "iscclosure missing")
    assert2(iscclosure(print) == true,  "print should be a C closure")
    assert2(iscclosure(function() end) == false, "lua fn should not be C closure")
end)

run("islclosure", "Closures", function()
    assert2(islclosure ~= nil, "islclosure missing")
    assert2(islclosure(function() end) == true,  "lua fn should be an L closure")
    assert2(islclosure(print) == false, "print should not be an L closure")
end)

run("isexecutorclosure", "Closures", function()
    assert2(isexecutorclosure ~= nil, "isexecutorclosure missing")
    local ef = isexecutorclosure
    -- the function checking should itself be executor-made
    assert2(type(isexecutorclosure(ef)) == "boolean", "should return boolean")
    -- a game closure definitely should not be executor-made
    assert2(isexecutorclosure(print) == false, "print is not an executor closure")
end)

run("checkcaller", "Closures", function()
    assert2(checkcaller ~= nil, "checkcaller missing")
    assert2(checkcaller() == true, "checkcaller() should return true from executor context")
end)

run("newcclosure", "Closures", function()
    assert2(newcclosure ~= nil, "newcclosure missing")
    local function lf() return 42 end
    local cc = newcclosure(lf)
    assert2(iscclosure(cc), "result of newcclosure should be a C closure")
    assert2(cc() == 42, "wrapped function should still return correctly")
end)

run("clonefunction", "Closures", function()
    assert2(clonefunction ~= nil, "clonefunction missing")
    local function orig(x) return x * 2 end
    local cloned = clonefunction(orig)
    assert2(cloned ~= orig, "clone should be a different reference")
    assert2(cloned(5) == 10, "clone should behave identically")
end)

run("hookfunction", "Closures", function()
    assert2(hookfunction ~= nil, "hookfunction missing")
    -- use a named global so the hook target is unambiguous across executors
    local function hookTarget() return "original" end
    local returned = hookfunction(hookTarget, newcclosure and newcclosure(function() return "hooked" end) or function() return "hooked" end)
    -- hookfunction must return the original (some executors call it replacewith)
    assert2(type(returned) == "function", "hookfunction should return the original function")
    assert2(hookTarget() == "hooked", "hook should intercept call")
end)

run("restorefunction", "Closures", function()
    assert2(restorefunction ~= nil, "restorefunction missing")
    -- fresh independent target — do NOT reuse the one from hookfunction test
    local function restoreTarget() return "before" end
    hookfunction(restoreTarget, function() return "after" end)
    assert2(restoreTarget() == "after", "hook must be active before restore")
    restorefunction(restoreTarget)
    assert2(restoreTarget() == "before", "restore should revert to original behaviour")
end)

run("hookmetamethod", "Closures", function()
    assert2(hookmetamethod ~= nil, "hookmetamethod missing")
    local obj = setmetatable({}, {
        __index = function(_, k) return k end,
        __metatable = "locked",
    })
    local original = hookmetamethod(obj, "__index", function(self, k)
        return k .. "_hooked"
    end)
    assert2(type(original) == "function", "should return original metamethod")
    assert2(obj.test == "test_hooked", "hook should intercept __index")
end)

run("getfunctionhash", "Closures", function()
    assert2(getfunctionhash ~= nil, "getfunctionhash missing")
    local function f() return 1 end
    local h = getfunctionhash(f)
    typecheck(h, "string", "getfunctionhash return")
    assert2(#h > 0, "hash should be non-empty")
    assert2(h == getfunctionhash(f), "hash should be stable for same function")
end)

run("loadstring", "Closures", function()
    assert2(loadstring ~= nil, "loadstring missing")
    local fn, err = loadstring("return 1 + 1")
    assert2(fn ~= nil, "loadstring compile error: " .. tostring(err))
    assert2(fn() == 2, "loadstring result incorrect")
end)

-- ───────────────────────────────────────────────────────────
--  DEBUG
-- ───────────────────────────────────────────────────────────
banner("Debug")

run("debug.getconstants", "Debug", function()
    assert2(debug.getconstants ~= nil, "debug.getconstants missing")
    local function f() local _ = "hello" return 42 end
    local consts = debug.getconstants(f)
    typecheck(consts, "table", "debug.getconstants return")
end)

run("debug.getconstant", "Debug", function()
    assert2(debug.getconstant ~= nil, "debug.getconstant missing")
    local function f() return "hi" end
    local consts = debug.getconstants(f)
    if #consts > 0 then
        local v = debug.getconstant(f, 1)
        assert2(v ~= nil, "should return a value")
    end
end)

run("debug.setconstant", "Debug", function()
    assert2(debug.setconstant ~= nil, "debug.setconstant missing")
    -- clone so we don't corrupt anything if the test is re-run
    local function base() return "setconstant_sentinel" end
    local f = clonefunction and clonefunction(base) or base
    local idx
    for i, v in ipairs(debug.getconstants(f)) do
        if v == "setconstant_sentinel" then idx = i break end
    end
    assert2(idx ~= nil, "sentinel constant not found — getconstants may be broken")
    debug.setconstant(f, idx, "patched")
    assert2(f() == "patched", "setconstant should change the returned constant")
end)

run("debug.getupvalues", "Debug", function()
    assert2(debug.getupvalues ~= nil, "debug.getupvalues missing")
    local x = 10
    local function f() return x end
    local ups = debug.getupvalues(f)
    typecheck(ups, "table", "debug.getupvalues return")
end)

run("debug.getupvalue", "Debug", function()
    assert2(debug.getupvalue ~= nil, "debug.getupvalue missing")
    local x = 99
    local function f() return x end
    local ups = debug.getupvalues(f)
    if #ups > 0 then
        local v = debug.getupvalue(f, 1)
        assert2(v == 99, "upvalue should equal x")
    end
end)

run("debug.setupvalue", "Debug", function()
    assert2(debug.setupvalue ~= nil, "debug.setupvalue missing")
    local x = 1
    local function f() return x end
    debug.setupvalue(f, 1, 999)
    assert2(f() == 999, "setupvalue should change upvalue")
end)

run("debug.getprotos", "Debug", function()
    assert2(debug.getprotos ~= nil, "debug.getprotos missing")
    local function f()
        local function inner() end
        return inner
    end
    local protos = debug.getprotos(f)
    typecheck(protos, "table", "debug.getprotos return")
end)

run("debug.getproto", "Debug", function()
    assert2(debug.getproto ~= nil, "debug.getproto missing")
    local function f()
        local function inner() return 7 end
        return inner
    end
    local protos = debug.getprotos(f)
    if #protos > 0 then
        local p = debug.getproto(f, 1, true)
        assert2(type(p) == "function", "getproto should return a function")
    end
end)

run("debug.getstack", "Debug", function()
    assert2(debug.getstack ~= nil, "debug.getstack missing")
    local function inner()
        local s = debug.getstack(1)
        typecheck(s, "table", "debug.getstack return")
    end
    inner()
end)

run("debug.setstack", "Debug", function()
    assert2(debug.setstack ~= nil, "debug.setstack missing")
    -- just verify it exists and is callable; stack manipulation is frame-dependent
    assert2(type(debug.setstack) == "function", "debug.setstack should be a function")
end)

-- ───────────────────────────────────────────────────────────
--  DRAWING
-- ───────────────────────────────────────────────────────────
banner("Drawing")

run("Drawing.new", "Drawing.new", function()
    assert2(Drawing ~= nil, "Drawing missing")
    local line = Drawing.new("Line")
    assert2(line ~= nil, "Drawing.new should return an object")
    line:Remove()
end)

run("isrenderobj", "Drawing.new", function()
    assert2(isrenderobj ~= nil, "isrenderobj missing")
    local line = Drawing.new("Line")
    assert2(isrenderobj(line) == true, "Drawing object should pass isrenderobj")
    assert2(isrenderobj({}) == false, "plain table should fail isrenderobj")
    line:Remove()
end)

run("getrenderproperty", "Drawing.new", function()
    assert2(getrenderproperty ~= nil, "getrenderproperty missing")
    local line = Drawing.new("Line")
    local visible = getrenderproperty(line, "Visible")
    assert2(type(visible) == "boolean", "Visible should be boolean")
    line:Remove()
end)

run("setrenderproperty", "Drawing.new", function()
    assert2(setrenderproperty ~= nil, "setrenderproperty missing")
    local line = Drawing.new("Line")
    setrenderproperty(line, "Visible", false)
    assert2(getrenderproperty(line, "Visible") == false, "Visible should be false after set")
    line:Remove()
end)

run("cleardrawcache", "Drawing.new", function()
    assert2(cleardrawcache ~= nil, "cleardrawcache missing")
    local line = Drawing.new("Line")
    cleardrawcache()
    -- if we get here without error, pass
end)

-- ───────────────────────────────────────────────────────────
--  ENCODING
-- ───────────────────────────────────────────────────────────
banner("Encoding")

run("base64encode", "Encoding", function()
    assert2(base64encode ~= nil, "base64encode missing")
    local enc = base64encode("hello")
    assert2(enc == "aGVsbG8=", "base64encode('hello') should equal 'aGVsbG8='")
end)

run("base64decode", "Encoding", function()
    assert2(base64decode ~= nil, "base64decode missing")
    local dec = base64decode("aGVsbG8=")
    assert2(dec == "hello", "base64decode should round-trip")
end)

run("lz4compress", "Encoding", function()
    if lz4compress == nil then notSupported("lz4compress") return end
    local data = string.rep("abcd", 100)
    local compressed = lz4compress(data)
    typecheck(compressed, "string", "lz4compress return")
    assert2(#compressed > 0,       "compressed output should be non-empty")
    assert2(#compressed < #data,   "compressed should be smaller than input")
end)

run("lz4decompress", "Encoding", function()
    if lz4decompress == nil then notSupported("lz4decompress") return end
    if lz4compress == nil then
        -- decompress can't be tested without compress
        error("skip: lz4compress unavailable, cannot produce test payload")
    end
    local data = string.rep("abcd", 100)
    local compressed = lz4compress(data)
    local decompressed = lz4decompress(compressed, #data)
    assert2(decompressed == data, "lz4 round-trip failed")
end)

-- ───────────────────────────────────────────────────────────
--  ENVIRONMENT
-- ───────────────────────────────────────────────────────────
banner("Environment")

run("getgenv", "Environment", function()
    assert2(getgenv ~= nil, "getgenv missing")
    local env = getgenv()
    typecheck(env, "table", "getgenv return")
    -- should be shared: set a key and read it back
    getgenv().__sUNCtest = true
    assert2(getgenv().__sUNCtest == true, "getgenv should be persistent")
    getgenv().__sUNCtest = nil
end)

run("getrenv", "Environment", function()
    assert2(getrenv ~= nil, "getrenv missing")
    local env = getrenv()
    typecheck(env, "table", "getrenv return")
    -- game env should have print but not executor functions
    assert2(env.print ~= nil, "getrenv should contain print")
end)

run("getgc", "Environment", function()
    assert2(getgc ~= nil, "getgc missing")
    local gc = getgc()
    typecheck(gc, "table", "getgc return")
    assert2(#gc > 0, "getgc should return non-empty table")
end)

run("getreg", "Environment", function()
    assert2(getreg ~= nil, "getreg missing")
    local reg = getreg()
    typecheck(reg, "table", "getreg return")
end)

run("filtergc", "Environment", function()
    assert2(filtergc ~= nil, "filtergc missing")
    -- sUNC uses "include_executor" but older forks used "executor" — try both
    local fns = filtergc("function", { include_executor = false })
    if fns == nil then
        fns = filtergc("function", { executor = false })
    end
    typecheck(fns, "table", "filtergc return")
    assert2(#fns > 0, "filtergc should return at least some functions")
    for _, v in ipairs(fns) do
        assert2(type(v) == "function", "filtergc 'function' entries should all be functions")
        break
    end
    -- table variant
    local tbls = filtergc("table", {})
    typecheck(tbls, "table", "filtergc 'table' return")
    assert2(#tbls > 0, "filtergc should return at least some tables")
end)

-- ───────────────────────────────────────────────────────────
--  FILESYSTEM
-- ───────────────────────────────────────────────────────────
banner("Filesystem")

local FS_FOLDER = "sUNCtest"
local FS_FILE   = FS_FOLDER .. "/test.txt"
local FS_APPEND = FS_FOLDER .. "/append.txt"

run("makefolder", "filesys", function()
    assert2(makefolder ~= nil, "makefolder missing")
    makefolder(FS_FOLDER)
    assert2(isfolder(FS_FOLDER), "folder should exist after makefolder")
end)

run("isfolder", "filesys", function()
    assert2(isfolder ~= nil, "isfolder missing")
    assert2(isfolder(FS_FOLDER) == true,  "created folder should exist")
    assert2(isfolder("__nonexistent_sunc__") == false, "nonexistent folder should return false")
end)

run("writefile", "filesys", function()
    assert2(writefile ~= nil, "writefile missing")
    writefile(FS_FILE, "sUNC test content")
    assert2(isfile(FS_FILE), "file should exist after writefile")
end)

run("isfile", "filesys", function()
    assert2(isfile ~= nil, "isfile missing")
    assert2(isfile(FS_FILE) == true, "written file should exist")
    assert2(isfile("__nonexistent_sunc__.txt") == false, "nonexistent file should return false")
end)

run("readfile", "filesys", function()
    assert2(readfile ~= nil, "readfile missing")
    local content = readfile(FS_FILE)
    assert2(content == "sUNC test content", "readfile should return written content")
end)

run("appendfile", "filesys", function()
    assert2(appendfile ~= nil, "appendfile missing")
    writefile(FS_APPEND, "line1")
    appendfile(FS_APPEND, "\nline2")
    local content = readfile(FS_APPEND)
    assert2(content == "line1\nline2", "appendfile should append correctly")
end)

run("listfiles", "filesys", function()
    assert2(listfiles ~= nil, "listfiles missing")
    local files = listfiles(FS_FOLDER)
    typecheck(files, "table", "listfiles return")
    assert2(#files >= 1, "listfiles should return at least one file")
end)

run("loadfile", "filesys", function()
    assert2(loadfile ~= nil, "loadfile missing")
    writefile(FS_FOLDER .. "/load.lua", "return 1 + 1")
    local fn, err = loadfile(FS_FOLDER .. "/load.lua")
    assert2(fn ~= nil, "loadfile should compile: " .. tostring(err))
    assert2(fn() == 2, "loadfile result incorrect")
end)

run("getcustomasset", "filesys", function()
    assert2(getcustomasset ~= nil, "getcustomasset missing")
    -- write a small png placeholder (1x1 transparent png)
    local PNG = "\137PNG\r\n\26\n\0\0\0\rIHDR\0\0\0\1\0\0\0\1\8\6\0\0\0\31\21\196\137\0\0\0\nIDATx\156c\248\15\0\0\1\1\0\5\24\213\78\0\0\0\0IEND\174B`\130"
    writefile(FS_FOLDER .. "/test.png", PNG)
    local rbxAsset = getcustomasset(FS_FOLDER .. "/test.png")
    typecheck(rbxAsset, "string", "getcustomasset return")
    assert2(rbxAsset:find("rbxasset://") or rbxAsset:find("rbxtemp://"),
        "getcustomasset should return an rbx URI")
end)

run("delfile", "filesys", function()
    assert2(delfile ~= nil, "delfile missing")
    local tmp = FS_FOLDER .. "/tmp.txt"
    writefile(tmp, "delete me")
    delfile(tmp)
    assert2(not isfile(tmp), "file should be gone after delfile")
end)

run("delfolder", "filesys", function()
    assert2(delfolder ~= nil, "delfolder missing")
    local tmpdir = FS_FOLDER .. "/tmpdir"
    makefolder(tmpdir)
    delfolder(tmpdir)
    assert2(not isfolder(tmpdir), "folder should be gone after delfolder")
end)

-- cleanup
pcall(function()
    for _, f in ipairs(listfiles(FS_FOLDER)) do pcall(delfile, f) end
    pcall(delfolder, FS_FOLDER)
end)

-- ───────────────────────────────────────────────────────────
--  INSTANCES
-- ───────────────────────────────────────────────────────────
banner("Instances")

run("getinstances", "Instances", function()
    assert2(getinstances ~= nil, "getinstances missing")
    local list = getinstances()
    typecheck(list, "table", "getinstances return")
    assert2(#list > 0, "getinstances should return at least some instances")
    assert2(typeof(list[1]) == "Instance", "getinstances entries should be Instances")
end)

run("getnilinstances", "Instances", function()
    assert2(getnilinstances ~= nil, "getnilinstances missing")
    local list = getnilinstances()
    typecheck(list, "table", "getnilinstances return")
end)

run("gethui", "Instances", function()
    assert2(gethui ~= nil, "gethui missing")
    local hui = gethui()
    assert2(typeof(hui) == "Instance", "gethui should return an Instance")
end)

run("cloneref", "cloneref", function()
    assert2(cloneref ~= nil, "cloneref missing")
    local ws = game:GetService("Workspace")
    local clone = cloneref(ws)
    assert2(clone ~= ws, "cloneref should return a different reference")
    assert2(compareinstances(clone, ws), "cloneref should still compare equal via compareinstances")
end)

run("compareinstances", "cloneref", function()
    assert2(compareinstances ~= nil, "compareinstances missing")
    local ws = game:GetService("Workspace")
    local clone = cloneref(ws)
    assert2(compareinstances(ws, ws) == true,  "same ref should be equal")
    assert2(compareinstances(clone, ws) == true, "cloneref should compare equal")
    assert2(compareinstances(ws, game) == false, "different instances should not be equal")
end)

run("getcallbackvalue", "Instances", function()
    assert2(getcallbackvalue ~= nil, "getcallbackvalue missing")
    local ss = Instance.new("ScreenGui")
    -- just verify the call doesn't error on a valid instance + property
    -- BindableFunction has OnInvoke as a callback
    local bf = Instance.new("BindableFunction")
    bf.OnInvoke = function() end
    local cb = getcallbackvalue(bf, "OnInvoke")
    assert2(type(cb) == "function", "getcallbackvalue should return the callback function")
    bf:Destroy()
    ss:Destroy()
end)

run("fireclickdetector", "Instances", function()
    assert2(fireclickdetector ~= nil, "fireclickdetector missing")
    local part = Instance.new("Part")
    local cd = Instance.new("ClickDetector", part)
    fireclickdetector(cd, 0)
    -- no error = pass
    cd:Destroy()
    part:Destroy()
end)

run("firetouchinterest", "Instances", function()
    assert2(firetouchinterest ~= nil, "firetouchinterest missing")
    local char = game.Players.LocalPlayer and game.Players.LocalPlayer.Character
    if not char then
        -- no character loaded yet — can't meaningfully test, mark untested
        results.passed -= 0  -- undo the upcoming pass by bailing via error
        error("skip: no character loaded (join a game first)")
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    assert2(root ~= nil, "HumanoidRootPart not found in character")
    local part = Instance.new("Part")
    part.Parent = workspace
    firetouchinterest(part, root, 0)  -- touch begin
    firetouchinterest(part, root, 1)  -- touch end
    part:Destroy()
end)

run("fireproximityprompt", "Instances", function()
    assert2(fireproximityprompt ~= nil, "fireproximityprompt missing")
    local part = Instance.new("Part")
    local pp = Instance.new("ProximityPrompt", part)
    fireproximityprompt(pp)
    pp:Destroy()
    part:Destroy()
end)

-- ───────────────────────────────────────────────────────────
--  METATABLE
-- ───────────────────────────────────────────────────────────
banner("Metatable")

run("getrawmetatable", "Metatable", function()
    assert2(getrawmetatable ~= nil, "getrawmetatable missing")
    local t = setmetatable({}, { __index = function() return 1 end, __metatable = "locked" })
    local mt = getrawmetatable(t)
    typecheck(mt, "table", "getrawmetatable return")
    assert2(mt.__index ~= nil, "raw metatable should contain __index")
end)

run("setrawmetatable", "Metatable", function()
    assert2(setrawmetatable ~= nil, "setrawmetatable missing")
    local t = setmetatable({}, { __metatable = "locked" })
    local newmt = { __index = function() return 42 end }
    setrawmetatable(t, newmt)
    assert2(t.anything == 42, "setrawmetatable should apply the new metatable")
end)

run("isreadonly", "Metatable", function()
    assert2(isreadonly ~= nil, "isreadonly missing")
    local t = {}
    assert2(isreadonly(t) == false, "plain table should not be readonly")
    setreadonly(t, true)
    assert2(isreadonly(t) == true, "table should be readonly after setreadonly")
    setreadonly(t, false)
end)

run("setreadonly", "Metatable", function()
    assert2(setreadonly ~= nil, "setreadonly missing")
    local t = { x = 1 }
    setreadonly(t, true)
    -- some executors throw, some silently ignore writes — check isreadonly instead
    -- of relying on pcall since error type varies wildly
    assert2(isreadonly(t) == true, "table should be readonly after setreadonly(true)")
    -- attempt the write but don't assert on the pcall result
    pcall(function() t.x = 2 end)
    setreadonly(t, false)
    assert2(isreadonly(t) == false, "table should not be readonly after setreadonly(false)")
    t.x = 99
    assert2(t.x == 99, "write should succeed after setreadonly(false)")
end)

run("getnamecallmethod", "Metatable", function()
    assert2(getnamecallmethod ~= nil, "getnamecallmethod missing")
    assert2(hookmetamethod ~= nil,    "hookmetamethod required for getnamecallmethod test")
    assert2(getrawmetatable ~= nil,   "getrawmetatable required for getnamecallmethod test")
    local captured
    local old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(function(self, ...)
        captured = getnamecallmethod()
        return old(self, ...)
    end) or function(self, ...)
        captured = getnamecallmethod()
        return old(self, ...)
    end)
    pcall(function() game:GetService("Workspace") end)
    -- always restore before asserting so a failure doesn't leave the hook live
    hookmetamethod(game, "__namecall", old)
    assert2(captured == "GetService",
        "getnamecallmethod should return 'GetService', got: " .. tostring(captured))
end)

-- ───────────────────────────────────────────────────────────
--  MISCELLANEOUS
-- ───────────────────────────────────────────────────────────
banner("Miscellaneous")

run("identifyexecutor", "Miscellaneous", function()
    assert2(identifyexecutor ~= nil, "identifyexecutor missing")
    local name, version = identifyexecutor()
    typecheck(name, "string", "identifyexecutor name")
    assert2(#name > 0, "executor name should be non-empty")
end)

run("request", "Miscellaneous", function()
    assert2(request ~= nil or http ~= nil or http_request ~= nil, "no http function found")
    local req = request or (http and http.request) or http_request
    local res = req({
        Url    = "https://httpbin.org/get",
        Method = "GET",
    })
    typecheck(res, "table", "request return")
    assert2(res.StatusCode == 200, "request should return 200: got " .. tostring(res.StatusCode))
    typecheck(res.Body, "string", "request Body")
end)

-- ───────────────────────────────────────────────────────────
--  REFLECTION
-- ───────────────────────────────────────────────────────────
banner("Reflection")

run("getthreadidentity", "Reflection", function()
    assert2(getthreadidentity ~= nil or getidentity ~= nil, "getthreadidentity missing")
    local fn = getthreadidentity or getidentity
    local id = fn()
    typecheck(id, "number", "getthreadidentity return")
    assert2(id >= 0, "identity should be >= 0")
end)

run("setthreadidentity", "Reflection", function()
    assert2(setthreadidentity ~= nil or setidentity ~= nil, "setthreadidentity missing")
    local set = setthreadidentity or setidentity
    local get = getthreadidentity or getidentity
    local old = get()
    set(6)
    assert2(get() == 6, "identity should be 6 after set")
    set(old)
end)

run("isscriptable", "Reflection", function()
    assert2(isscriptable ~= nil, "isscriptable missing")
    local cam = workspace.CurrentCamera
    -- FOV is scriptable, some internal props are not
    assert2(isscriptable(cam, "FieldOfView") == true, "FieldOfView should be scriptable")
end)

run("setscriptable", "Reflection", function()
    assert2(setscriptable ~= nil, "setscriptable missing")
    local part = Instance.new("Part")
    -- LocalTransparencyModifier is a known non-scriptable property
    local was = isscriptable(part, "LocalTransparencyModifier") or false
    setscriptable(part, "LocalTransparencyModifier", true)
    assert2(isscriptable(part, "LocalTransparencyModifier") == true,
        "property should be scriptable after setscriptable")
    setscriptable(part, "LocalTransparencyModifier", was)
    part:Destroy()
end)

run("gethiddenproperty", "Reflection", function()
    assert2(gethiddenproperty ~= nil, "gethiddenproperty missing")
    local part = Instance.new("Part")
    local val, isHidden = gethiddenproperty(part, "LocalTransparencyModifier")
    assert2(val ~= nil, "should return a value")
    assert2(type(isHidden) == "boolean", "second return should be boolean")
    part:Destroy()
end)

run("sethiddenproperty", "Reflection", function()
    assert2(sethiddenproperty ~= nil, "sethiddenproperty missing")
    local part = Instance.new("Part")
    sethiddenproperty(part, "LocalTransparencyModifier", 0.5)
    local val = gethiddenproperty(part, "LocalTransparencyModifier")
    assert2(math.abs(val - 0.5) < 0.001, "hidden property value should be 0.5")
    part:Destroy()
end)

-- ───────────────────────────────────────────────────────────
--  SCRIPTS
-- ───────────────────────────────────────────────────────────
banner("Scripts")

run("getscripts", "Scripts", function()
    assert2(getscripts ~= nil, "getscripts missing")
    local scripts = getscripts()
    typecheck(scripts, "table", "getscripts return")
    assert2(#scripts > 0, "should find at least one script")
end)

run("getrunningscripts", "Scripts", function()
    assert2(getrunningscripts ~= nil, "getrunningscripts missing")
    local running = getrunningscripts()
    typecheck(running, "table", "getrunningscripts return")
    assert2(#running > 0, "at least this script should be running")
end)

run("getloadedmodules", "Scripts", function()
    assert2(getloadedmodules ~= nil, "getloadedmodules missing")
    local mods = getloadedmodules()
    typecheck(mods, "table", "getloadedmodules return")
end)

run("getscriptbytecode", "Scripts", function()
    assert2(getscriptbytecode ~= nil, "getscriptbytecode missing")
    local scripts = getscripts()
    for _, s in ipairs(scripts) do
        if s:IsA("LocalScript") or s:IsA("ModuleScript") then
            local bc = getscriptbytecode(s)
            typecheck(bc, "string", "getscriptbytecode return")
            assert2(#bc > 0, "bytecode should be non-empty")
            return
        end
    end
end)

run("getscripthash", "Scripts", function()
    assert2(getscripthash ~= nil, "getscripthash missing")
    local scripts = getscripts()
    for _, s in ipairs(scripts) do
        if s:IsA("LocalScript") or s:IsA("ModuleScript") then
            local h = getscripthash(s)
            typecheck(h, "string", "getscripthash return")
            assert2(#h > 0, "hash should be non-empty")
            return
        end
    end
end)

run("getscriptclosure", "Scripts", function()
    assert2(getscriptclosure ~= nil, "getscriptclosure missing")
    local scripts = getscripts()
    for _, s in ipairs(scripts) do
        if s:IsA("LocalScript") or s:IsA("ModuleScript") then
            local fn = getscriptclosure(s)
            assert2(type(fn) == "function", "getscriptclosure should return a function")
            return
        end
    end
end)

run("getsenv", "Scripts", function()
    assert2(getsenv ~= nil, "getsenv missing")
    local scripts = getrunningscripts()
    for _, s in ipairs(scripts) do
        local env = getsenv(s)
        if env then
            typecheck(env, "table", "getsenv return")
            return
        end
    end
end)

run("getcallingscript", "Scripts", function()
    assert2(getcallingscript ~= nil, "getcallingscript missing")
    -- should return nil or an Instance when called from executor context
    local cs = getcallingscript()
    assert2(cs == nil or typeof(cs) == "Instance",
        "getcallingscript should return nil or Instance")
end)

run("getscriptfromthread", "Scripts", function()
    assert2(getscriptfromthread ~= nil, "getscriptfromthread missing")
    local t = task.spawn(function()
        local s = getscriptfromthread(coroutine.running())
        assert2(s == nil or typeof(s) == "Instance",
            "getscriptfromthread should return nil or Instance")
    end)
end)

-- ───────────────────────────────────────────────────────────
--  SIGNALS
-- ───────────────────────────────────────────────────────────
banner("Signals")

run("getconnections", "Signals", function()
    assert2(getconnections ~= nil, "getconnections missing")
    local part = Instance.new("Part")
    local conn = part.Touched:Connect(function() end)
    local conns = getconnections(part.Touched)
    typecheck(conns, "table", "getconnections return")
    assert2(#conns >= 1, "should find at least our connection")
    -- Connection object fields
    local c = conns[1]
    assert2(type(c.Function)   == "function", "connection.Function should be a function")
    assert2(type(c.Enabled)    == "boolean",  "connection.Enabled should be boolean")
    assert2(type(c.Disconnect) == "function", "connection.Disconnect should be a function")
    conn:Disconnect()
    part:Destroy()
end)

run("firesignal", "Signals", function()
    assert2(firesignal ~= nil, "firesignal missing")
    local be = Instance.new("BindableEvent")
    local fired = false
    be.Event:Connect(function() fired = true end)
    firesignal(be.Event)
    task.wait()
    assert2(fired, "firesignal should fire the signal")
    be:Destroy()
end)

run("replicatesignal", "Signals", function()
    if replicatesignal == nil then notSupported("replicatesignal") return end
    -- just verify it's callable
    assert2(type(replicatesignal) == "function", "replicatesignal should be a function")
end)

-- ───────────────────────────────────────────────────────────
--  WEBSOCKET
-- ───────────────────────────────────────────────────────────
banner("WebSocket")

run("WebSocket.connect", "WebSocket", function()
    assert2(WebSocket ~= nil, "WebSocket missing")
    assert2(type(WebSocket.connect) == "function", "WebSocket.connect missing")
    -- use wss://echo.websocket.org as primary, fall back to shape-only check on failure
    -- (don't hard-fail just because a third-party server is down)
    local ok, ws = pcall(WebSocket.connect, "wss://echo.websocket.org")
    if not ok or ws == nil then
        -- try alternate
        ok, ws = pcall(WebSocket.connect, "wss://socketsbay.com/wss/v2/1/demo/")
    end
    assert2(ok and ws ~= nil,
        "WebSocket.connect failed on both echo servers — executor may not support WebSocket")
    -- validate the object contract regardless of which server responded
    assert2(type(ws.Send)  == "function", "ws.Send should be a function")
    assert2(type(ws.Close) == "function", "ws.Close should be a function")
    assert2(ws.OnMessage ~= nil, "ws.OnMessage should exist")
    assert2(ws.OnClose   ~= nil, "ws.OnClose should exist")
    -- send a ping and verify we don't crash (don't assert the response — server-dependent)
    pcall(function() ws:Send("ping") end)
    ws:Close()
end)

-- ───────────────────────────────────────────────────────────
--  RESULTS SUMMARY
-- ───────────────────────────────────────────────────────────
task.wait(0.1)
local total  = results.passed + results.failed + results.untested
local tested = results.passed + results.failed
local score  = tested > 0 and math.floor((results.passed / tested) * 100 + 0.5) or 0

local function bar(width, filled)
    return string.rep("█", filled) .. string.rep("░", width - filled)
end

local W    = 46
local BARW = W - 18
local exec = tostring(identifyexecutor and identifyexecutor() or "unknown")

print(string.rep("═", W))
print(string.format("  sUNC RESULTS — %s", exec))
print(string.rep("═", W))
print(string.format("  %-9s: %d", "Passed",   results.passed))
print(string.format("  %-9s: %d", "Failed",   results.failed))
print(string.format("  %-9s: %d", "Untested", results.untested))
print(string.format("  %-9s: %d", "Total",    total))
print("  " .. string.rep("─", W - 4))
print(string.format("  %-9s: %s %3d%%", "Score",
    bar(BARW, math.floor(score / 100 * BARW + 0.5)), score))
print(string.format("             %d / %d tests passed", results.passed, tested))
print(string.rep("═", W))
