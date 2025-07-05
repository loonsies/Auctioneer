local chat = require('chat')
local ffi = require('ffi')

ffi.cdef [[
typedef void* HANDLE;
typedef unsigned long DWORD;
typedef void* LPVOID;
typedef DWORD (__stdcall *LPTHREAD_START_ROUTINE)(LPVOID);

HANDLE CreateThread(
  LPVOID lpThreadAttributes,
  DWORD dwStackSize,
  LPTHREAD_START_ROUTINE lpStartAddress,
  LPVOID lpParameter,
  DWORD dwCreationFlags,
  DWORD *lpThreadId
);

DWORD WaitForSingleObject(
  HANDLE hHandle,
  DWORD  dwMilliseconds
);

int CloseHandle(HANDLE hObject);

static const int INFINITE = 0xFFFFFFFF;
]]

local thread = {}

function thread.start(func)
    local t = {}
    t.cb = ffi.cast('DWORD (__stdcall*)(void*)', function (param)
        local ok, err = pcall(func)
        if not ok then
            print('Thread callback error:', err)
        end
        return 0
    end)

    t.handle = ffi.C.CreateThread(nil, 0, t.cb, nil, 0, nil)
    if t.handle == nil then
        t.cb:free()
        return nil
    end

    function t:wait(timeout)
        timeout = timeout or ffi.C.INFINITE
        return ffi.C.WaitForSingleObject(self.handle, timeout)
    end

    function t:close()
        if self.handle ~= nil then
            ffi.C.CloseHandle(self.handle)
        end

        if self.cb ~= nil then
            self.cb:free()
        end

        self.handle = nil
        self.cb = nil
    end

    return t
end

return thread
