-----------------------------------------------------------------------------
-- Non-blocking HTTP(S) client for Ashita addons
-- Handles HTTP and HTTPS requests without blocking the main thread
-- Call processAll() from your d3d_present callback to advance requests
-----------------------------------------------------------------------------

local socket = require('socket')
local url = require('socket.url')
local ssl = require('socket.ssl')
local nonBlockingRequests = {}

-- Settings
local DEBUG = false
local READ_CHUNK_SIZE = 8192
local CONNECT_TIMEOUT = 0
local CONNECTION_TIMEOUT = 15
local HANDSHAKE_TIMEOUT = 15
local MAX_REDIRECTS = 5

-- Request states
local REQUEST_STATE = {
    INIT = 1,
    CONNECTING = 2,
    SSL_HANDSHAKE = 3,
    SENDING_REQUEST = 4,
    RECEIVING_STATUS = 5,
    RECEIVING_HEADERS = 6,
    RECEIVING_BODY = 7,
    COMPLETE = 8,
    ERROR = 9
}

-- Active requests storage
local activeRequests = {}
local nextRequestId = 1

local function log(target, message, force)
    if message == nil then
        message = target
        target = nil
    end

    local shouldLog = force == true
    if not shouldLog then
        if target then
            shouldLog = DEBUG or target.debug
        else
            shouldLog = DEBUG
        end
    end

    if not shouldLog then
        return
    end

    local prefix = '[HTTP]'
    if target then
        local parts = {}
        if target.id then table.insert(parts, '#' .. tostring(target.id)) end
        if target.method then table.insert(parts, target.method) end
        if target.url then table.insert(parts, target.url) end
        if #parts > 0 then
            prefix = prefix .. ' ' .. table.concat(parts, ' ')
        end
    end

    print(prefix .. ' ' .. tostring(message))
end

-- Create TCP socket for HTTP/HTTPS requests
local function createSocket(isSecure)
    local sock = socket.tcp()
    if not sock then
        return nil, 'Failed to create TCP socket'
    end

    log('Created TCP socket for ' .. (isSecure and 'HTTPS' or 'HTTP'))
    return sock, nil
end

-- Clean up request resources
local function cleanupRequest(request)
    if request.socket then
        pcall(request.socket.close, request.socket)
        request.socket = nil
    end
    -- Clear large data structures
    request.requestData = nil
    request.responseBody = nil
end

local function resetForRedirect(request)
    request.state = REQUEST_STATE.INIT
    request.socket = nil
    request.connectAttempted = nil
    request.connectStartTime = nil
    request.handshakeStart = nil
    request.headerLines = {}
    request.responseHeaders = {}
    request.responseBody = {}
    request.requestData = nil
    request.sentBytes = 0
    request.receivedBodyBytes = 0
    request.contentLength = nil
    request.statusCode = nil
    request.statusMessage = nil
    request.isChunked = false
    request.chunkSize = nil
    request.chunkBytesRead = 0
    request.expectingChunkTerminator = false
    request.awaitingTrailer = false
    request.terminatorBuffer = nil
end

-- Build HTTP request string
local function buildRequest(method, parsedUrl, requestHeaders, body)
    local uri = parsedUrl.path
    if parsedUrl.query then
        uri = uri .. '?' .. parsedUrl.query
    end

    local requestLine = method .. ' ' .. uri .. ' HTTP/1.1\r\n'

    local headers = {
        ['Host'] = parsedUrl.host .. (parsedUrl.port ~= (parsedUrl.isSecure and 443 or 80) and ':' .. parsedUrl.port or ''),
        ['Connection'] = 'close',
        ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:144.0) Gecko/20100101 Firefox/144.0',
    }

    if body and #body > 0 then
        headers['Content-Length'] = tostring(#body)
        if not (requestHeaders and requestHeaders['Content-Type']) then
            headers['Content-Type'] = 'application/x-www-form-urlencoded'
        end
    end

    if requestHeaders then
        for k, v in pairs(requestHeaders) do
            headers[k] = v
        end
    end

    local headerString = ''
    for k, v in pairs(headers) do
        headerString = headerString .. k .. ': ' .. v .. '\r\n'
    end
    headerString = headerString .. '\r\n'

    local requestData = requestLine .. headerString
    if body and #body > 0 then
        requestData = requestData .. body
    end

    return requestData
end

local function prepareHttpRequest(request)
    request.requestData = buildRequest(request.method, request.parsedUrl, request.headers, request.body)
    request.sentBytes = 0
    log(request, 'HTTP request prepared, bytes: ' .. #request.requestData)
end

local function beginHandshake(request)
    log(request, 'Setting up SSL for ' .. request.parsedUrl.host)

    local ip, port = request.socket:getsockname()
    if not ip or not port then
        request.state = REQUEST_STATE.ERROR
        request.error = 'Socket not connected before SSL'
        cleanupRequest(request)
        return false
    end

    local sslParams = {
        mode = 'client',
        protocol = 'any',
        options = { 'all', 'no_sslv2', 'no_sslv3', 'no_tlsv1', 'no_tlsv1_1' },
        verify = 'none',
        sni = request.parsedUrl.host
    }

    local sslSock, err = ssl.wrap(request.socket, sslParams)
    if not sslSock then
        request.state = REQUEST_STATE.ERROR
        request.error = 'SSL setup failed: ' .. (err or 'unknown')
        log(request, request.error)
        cleanupRequest(request)
        return false
    end

    request.socket = sslSock
    pcall(function () sslSock:sni(request.parsedUrl.host) end)
    sslSock:settimeout(0)

    request.state = REQUEST_STATE.SSL_HANDSHAKE
    request.handshakeStart = os.clock()
    log(request, 'SSL handshake started for ' .. request.parsedUrl.host)
    return true
end

local function completeConnect(request)
    log(request, 'Connection established to ' .. request.parsedUrl.host)

    request.connectionTime = os.clock()

    local ok, peerIp, peerPort = pcall(request.socket.getpeername, request.socket)
    if ok and peerIp then
        log(request, 'Connected to peer: ' .. tostring(peerIp) .. ':' .. tostring(peerPort))
    end

    local okLocal, localIp, localPort = pcall(request.socket.getsockname, request.socket)
    if okLocal and localIp then
        log(request, 'Local socket: ' .. tostring(localIp) .. ':' .. tostring(localPort))
    end

    if request.parsedUrl.isSecure then
        beginHandshake(request)
    else
        prepareHttpRequest(request)
        request.state = REQUEST_STATE.SENDING_REQUEST
    end
end

local function handleChunkedBody(request)
    if request.expectingChunkTerminator then
        local needed = 2 - #(request.terminatorBuffer or '')
        local data, err, partial = request.socket:receive(needed)
        local chunk = data or partial
        if chunk and #chunk > 0 then
            request.terminatorBuffer = (request.terminatorBuffer or '') .. chunk
            if #request.terminatorBuffer >= 2 then
                request.expectingChunkTerminator = false
                request.terminatorBuffer = nil
                request.chunkSize = nil
                request.chunkBytesRead = 0
            end
        end

        if request.expectingChunkTerminator then
            if err == 'timeout' or err == 'wantread' or err == nil then
                return false
            elseif err == 'closed' then
                return nil, 'Connection closed while reading chunk end'
            else
                return nil, err or 'Chunk terminator error'
            end
        end
    end

    if request.awaitingTrailer then
        local line, err = request.socket:receive('*l')
        if line then
            if line == '' then
                return true
            end
            return false
        elseif err == 'timeout' or err == 'wantread' then
            return false
        elseif err == 'closed' then
            return true
        else
            return nil, err or 'Trailer read error'
        end
    end

    if not request.chunkSize then
        local line, err = request.socket:receive('*l')
        if line then
            local size = tonumber(line, 16)
            if not size then
                return nil, 'Invalid chunk size line'
            end
            if size == 0 then
                request.chunkSize = 0
                request.chunkBytesRead = 0
                request.awaitingTrailer = true
                return false
            end
            request.chunkSize = size
            request.chunkBytesRead = 0
        elseif err == 'timeout' or err == 'wantread' then
            return false
        elseif err == 'closed' then
            return nil, 'Connection closed before chunk size'
        else
            return nil, err or 'Chunk size read error'
        end
    end

    if request.chunkSize and request.chunkSize > 0 then
        local remaining = request.chunkSize - request.chunkBytesRead
        if remaining > 0 then
            local toRead = math.min(remaining, READ_CHUNK_SIZE)
            local data, err, partial = request.socket:receive(toRead)
            local chunk = data or partial
            if chunk and #chunk > 0 then
                table.insert(request.responseBody, chunk)
                request.chunkBytesRead = request.chunkBytesRead + #chunk
                request.receivedBodyBytes = request.receivedBodyBytes + #chunk
            end

            if request.chunkBytesRead < request.chunkSize then
                if err == 'timeout' or err == 'wantread' or err == nil then
                    return false
                elseif err == 'closed' then
                    return nil, 'Connection closed mid-chunk'
                else
                    return nil, err or 'Chunk read error'
                end
            end

            request.expectingChunkTerminator = true
            return false
        end
    end

    return false
end

local function handlePlainBody(request)
    local bytesToRead = READ_CHUNK_SIZE
    if request.contentLength then
        local remaining = request.contentLength - request.receivedBodyBytes
        if remaining <= 0 then
            return true
        end
        bytesToRead = math.min(bytesToRead, remaining)
    end

    local data, err, partial = request.socket:receive(bytesToRead)
    local chunk = data or partial

    if chunk and #chunk > 0 then
        table.insert(request.responseBody, chunk)
        request.receivedBodyBytes = request.receivedBodyBytes + #chunk
    end

    if request.contentLength and request.receivedBodyBytes >= request.contentLength then
        return true
    end

    if err == 'timeout' or err == 'wantread' or err == nil then
        return false
    elseif err == 'closed' then
        if not request.contentLength or request.receivedBodyBytes >= (request.contentLength or 0) then
            return true
        end
        return nil, 'Connection closed before body finished'
    else
        return nil, err or 'Body read error'
    end
end

-- Parse URL and validate
local function parseURL(fullUrl)
    if not fullUrl or type(fullUrl) ~= 'string' or fullUrl == '' then
        error('Invalid URL: empty or non-string')
    end

    local parsed = url.parse(fullUrl)
    if not parsed or not parsed.scheme or not parsed.host then
        error('Invalid URL: ' .. fullUrl)
    end

    if parsed.scheme ~= 'http' and parsed.scheme ~= 'https' then
        error('Unsupported scheme: ' .. parsed.scheme)
    end

    local isSecure = parsed.scheme == 'https'
    local port = parsed.port or (isSecure and 443 or 80)

    return {
        scheme = parsed.scheme,
        host = parsed.host,
        port = port,
        path = parsed.path or '/',
        query = parsed.query,
        fragment = parsed.fragment,
        isSecure = isSecure
    }
end


-- Parse HTTP status line
local function parseStatusLine(line)
    local version, code, message = line:match('^HTTP/(%d+%.%d+) (%d+) (.*)$')
    if version and code then
        return tonumber(code), message:gsub('\r', '')
    end
    return nil, 'Invalid status line'
end

-- Parse response headers into table
local function parseHeaders(headerLines)
    local headers = {}
    for _, line in ipairs(headerLines) do
        local name, value = line:match('^([^:]+):%s*(.*)$')
        if name and value then
            headers[name:lower()] = value:gsub('\r', '')
        end
    end
    return headers
end

-- Resolve relative URL to absolute URL
local function resolveRedirectUrl(baseUrl, location)
    if location:match('^https?://') then
        -- Already absolute URL
        return location
    elseif location:match('^/') then
        -- Absolute path, combine with base domain
        local scheme, host, port = baseUrl:match('^(https?)://([^:/]+):?(%d*)')
        if scheme and host then
            local portPart = (port and port ~= '') and (':' .. port) or ''
            return scheme .. '://' .. host .. portPart .. location
        end
    else
        -- Relative path, combine with base URL path
        local basePart = baseUrl:match('^(.*/)')
        if basePart then
            return basePart .. location
        end
    end
    return location
end

-- Process a single request state
local function processRequest(request)
    if request.state == REQUEST_STATE.INIT then
        -- Parse URL and create socket
        local success, result = pcall(parseURL, request.url)
        if not success then
            request.state = REQUEST_STATE.ERROR
            request.error = 'URL parse error: ' .. tostring(result)
            log(request, 'URL parse failed: ' .. tostring(result))
            return
        end
        request.parsedUrl = result

        local sock, err = createSocket(request.parsedUrl.isSecure)
        if not sock then
            request.state = REQUEST_STATE.ERROR
            request.error = err or 'Failed to create socket'
            log(request, 'Socket creation failed: ' .. (err or 'unknown'))
            return
        end

        request.socket = sock

        -- Set non-blocking mode
        local success, err = pcall(function ()
            request.socket:settimeout(CONNECT_TIMEOUT)
        end)
        if not success then
            request.state = REQUEST_STATE.ERROR
            request.error = 'Socket timeout setup failed: ' .. tostring(err)
            log(request, 'Socket settimeout failed: ' .. tostring(err))
            cleanupRequest(request)
            return
        end

        request.state = REQUEST_STATE.CONNECTING
        request.connectStartTime = os.clock()
        log(request, 'Starting connection to ' .. request.parsedUrl.host .. ':' .. request.parsedUrl.port)
    elseif request.state == REQUEST_STATE.CONNECTING then
        -- Handle connection establishment
        if not request.connectAttempted then
            -- First connection attempt
            local result, err = request.socket:connect(request.parsedUrl.host, request.parsedUrl.port)
            request.connectAttempted = true

            if result == 1 then
                completeConnect(request)
                return
            elseif err == 'timeout' then
                log(request, 'Connection pending for ' .. request.parsedUrl.host)
                return -- Wait for writability
            else
                request.state = REQUEST_STATE.ERROR
                request.error = 'Connection failed: ' .. (err or 'unknown')
                log(request, 'Connection failed: ' .. (err or 'unknown'))
                cleanupRequest(request)
                return
            end
        else
            -- Wait until socket is writable to complete connect()
            local _, writable, selectErr = socket.select(nil, { request.socket }, 0)
            if selectErr and selectErr ~= 'timeout' then
                request.state = REQUEST_STATE.ERROR
                request.error = 'Socket select failed: ' .. tostring(selectErr)
                log(request, 'Socket select failed during connect: ' .. tostring(selectErr))
                cleanupRequest(request)
                return
            end

            if writable and #writable > 0 then
                local result, err = request.socket:connect(request.parsedUrl.host, request.parsedUrl.port)
                if result == 1 or err == 'already connected' then
                    completeConnect(request)
                    return
                elseif err == 'timeout' then
                    -- still negotiating
                    return
                else
                    request.state = REQUEST_STATE.ERROR
                    request.error = 'Connection failed during completion: ' .. (err or 'unknown')
                    log(request, 'Connection completion failed: ' .. (err or 'unknown'))
                    cleanupRequest(request)
                    return
                end
            elseif not writable or #writable == 0 then
                local elapsed = os.clock() - request.connectStartTime
                if elapsed > CONNECTION_TIMEOUT then
                    request.state = REQUEST_STATE.ERROR
                    request.error = 'Connection timeout after ' .. math.floor(elapsed) .. 's'
                    log(request, 'Connection timeout for ' .. request.url)
                    cleanupRequest(request)
                end
                return
            else
                local elapsed = os.clock() - request.connectStartTime
                if elapsed > CONNECTION_TIMEOUT then
                    request.state = REQUEST_STATE.ERROR
                    request.error = 'Connection timeout after ' .. math.floor(elapsed) .. 's'
                    log(request, 'Connection timeout for ' .. request.url)
                    cleanupRequest(request)
                else
                    return
                end
            end
        end
        return
    elseif request.state == REQUEST_STATE.SSL_HANDSHAKE then
        -- Complete SSL handshake
        if not request.socket then
            request.state = REQUEST_STATE.ERROR
            request.error = 'SSL handshake failed: Socket unavailable'
            log(request, 'SSL handshake failed: Socket unavailable for ' .. request.parsedUrl.host)
            cleanupRequest(request)
            return
        end

        local ok, result, err = pcall(request.socket.dohandshake, request.socket)
        if not ok then
            request.state = REQUEST_STATE.ERROR
            request.error = 'SSL handshake exception: ' .. tostring(result)
            log(request, 'SSL handshake exception for ' .. request.parsedUrl.host .. ': ' .. tostring(result))
            cleanupRequest(request)
            return
        end

        log(request, 'SSL handshake attempt: result=' .. tostring(result) .. ', err=' .. tostring(err))

        if result == 1 or result == true then
            log(request, 'SSL ready for ' .. request.parsedUrl.host)
            -- SSL handshake complete, prepare to send request
            request.state = REQUEST_STATE.SENDING_REQUEST
            prepareHttpRequest(request)
        elseif err == 'timeout' or err == 'wantread' or err == 'wantwrite' then
            -- Handshake in progress, check timeout
            local elapsed = os.clock() - request.handshakeStart
            log(request, 'SSL handshake in progress, elapsed: ' .. math.floor(elapsed) .. 's')
            if elapsed > HANDSHAKE_TIMEOUT then
                request.state = REQUEST_STATE.ERROR
                request.error = 'SSL handshake timeout after ' .. math.floor(elapsed) .. 's'
                log(request, 'SSL handshake timeout for ' .. request.url)
                cleanupRequest(request)
            end
        else
            request.state = REQUEST_STATE.ERROR
            request.error = 'SSL handshake failed: ' .. (err or 'unknown')
            log(request, 'SSL handshake failed: ' .. (err or 'unknown'))
            cleanupRequest(request)
        end
    elseif request.state == REQUEST_STATE.SENDING_REQUEST then
        -- Send request data
        local remaining = request.requestData:sub(request.sentBytes + 1)
        if #remaining == 0 then
            request.state = REQUEST_STATE.RECEIVING_STATUS
            request.headerLines = {}
            request.responseHeaders = {}
            request.responseBody = {}
            log(request, 'Request sent to ' .. request.url)
            return
        end

        -- Initialize send start time if not set
        if not request.sendStartTime then
            request.sendStartTime = os.clock()
        end

        -- Check for send timeout
        local elapsed = os.clock() - request.sendStartTime
        if elapsed > 10 then -- 10 second timeout for sending
            request.state = REQUEST_STATE.ERROR
            request.error = 'Send timeout after ' .. math.floor(elapsed) .. 's'
            log(request, 'Send timeout for ' .. request.url)
            cleanupRequest(request)
            return
        end

        local chunk = remaining
        -- For small requests (like HTTP headers), send everything at once
        if #remaining <= READ_CHUNK_SIZE * 4 then
            chunk = remaining
            log(request, 'Sending entire request at once: ' .. #chunk .. ' bytes')
        else
            chunk = remaining:sub(1, READ_CHUNK_SIZE)
            log(request, 'Sending chunk: ' .. #chunk .. ' bytes')
        end

        -- Temporarily set socket to blocking mode for send
        pcall(function () request.socket:settimeout(0.1) end) -- Very short timeout

        -- Check if socket is ready for writing using select
        local _, writeReady, selectErr = socket.select(nil, { request.socket }, 0)
        if selectErr or not writeReady or #writeReady == 0 then
            log(request, 'Socket not ready for writing: err=' .. tostring(selectErr) .. ', ready=' .. tostring(#(writeReady or {})))
            -- Try again next frame if not ready
            pcall(function () request.socket:settimeout(0) end)
            return
        end

        log(request, 'Socket ready for writing, sending ' .. #chunk .. ' bytes')
        local sent, err = request.socket:send(chunk)

        -- If send failed, try to get more detailed error information
        if not sent then
            log(request, 'Send failed with error: ' .. tostring(err))

            -- Try to read any response from server
            local errorResponse, readErr = request.socket:receive('*a')
            log(request, 'Server response after failed send: data=' .. tostring(errorResponse) .. ', err=' .. tostring(readErr))
        end

        pcall(function () request.socket:settimeout(0) end) -- Back to non-blocking

        if sent then
            request.sentBytes = request.sentBytes + sent
            log(request, 'Sent ' .. sent .. ' bytes, total: ' .. request.sentBytes .. '/' .. #request.requestData)
        elseif err == 'timeout' or err == 'wantwrite' then
            -- Keep trying, socket is just busy
            log(request, 'Send would block, retrying...')
        else
            request.state = REQUEST_STATE.ERROR
            request.error = 'Send error: ' .. (err or 'unknown')
            log(request, 'Send error: ' .. (err or 'unknown'))
            cleanupRequest(request)
        end
    elseif request.state == REQUEST_STATE.RECEIVING_STATUS then
        -- Get status line
        local data, err = request.socket:receive('*l')

        if data then
            local code, message = parseStatusLine(data)
            if code then
                request.statusCode = code
                request.statusMessage = message
                request.state = REQUEST_STATE.RECEIVING_HEADERS
                log(request, 'Status: ' .. code .. ' ' .. (message or ''))
            else
                request.state = REQUEST_STATE.ERROR
                request.error = 'Invalid status line: ' .. data
                cleanupRequest(request)
            end
        elseif err == 'timeout' or err == 'wantread' then
            -- Keep waiting
        elseif err == 'closed' then
            request.state = REQUEST_STATE.ERROR
            request.error = 'Connection closed during status'
            cleanupRequest(request)
        else
            request.state = REQUEST_STATE.ERROR
            request.error = 'Status receive error: ' .. (err or 'unknown')
            cleanupRequest(request)
        end
    elseif request.state == REQUEST_STATE.RECEIVING_HEADERS then
        -- Get headers line by line
        local data, err = request.socket:receive('*l')

        if data then
            if data == '' then
                -- End of headers
                request.responseHeaders = parseHeaders(request.headerLines)

                -- Check for redirect
                if request.statusCode >= 300 and request.statusCode < 400 then
                    local location = request.responseHeaders['location']
                    if location then
                        -- Initialize redirect counter if not exists
                        request.redirectCount = request.redirectCount or 0

                        if request.redirectCount >= MAX_REDIRECTS then
                            request.state = REQUEST_STATE.ERROR
                            request.error = 'Too many redirects (max ' .. MAX_REDIRECTS .. ')'
                            cleanupRequest(request)
                            return
                        end

                        -- Resolve redirect URL
                        local newUrl = resolveRedirectUrl(request.url, location)
                        log(request, 'Redirecting to: ' .. newUrl)

                        -- Update request for redirect
                        request.redirectCount = request.redirectCount + 1
                        request.url = newUrl

                        -- Parse new URL
                        local success, result = pcall(parseURL, newUrl)
                        if not success then
                            request.state = REQUEST_STATE.ERROR
                            request.error = 'Redirect URL parse error: ' .. tostring(result)
                            cleanupRequest(request)
                            return
                        end
                        request.parsedUrl = result

                        -- Clean up current connection and reset state
                        cleanupRequest(request)
                        resetForRedirect(request)
                        return
                    else
                        request.state = REQUEST_STATE.ERROR
                        request.error = 'Redirect status but no Location header'
                        cleanupRequest(request)
                        return
                    end
                end

                request.state = REQUEST_STATE.RECEIVING_BODY
                request.contentLength = tonumber(request.responseHeaders['content-length'])
                local transferEncoding = request.responseHeaders['transfer-encoding']
                if transferEncoding and transferEncoding:lower():find('chunked', 1, true) then
                    request.isChunked = true
                    request.chunkSize = nil
                    request.chunkBytesRead = 0
                    request.awaitingTrailer = false
                else
                    request.isChunked = false
                end
                request.receivedBodyBytes = 0
                log(request, 'Headers complete, content-length: ' .. (request.contentLength or 'chunked'))
            else
                table.insert(request.headerLines, data)
            end
        elseif err == 'timeout' or err == 'wantread' then
            -- Keep waiting
        elseif err == 'closed' then
            request.state = REQUEST_STATE.ERROR
            request.error = 'Connection closed during headers'
            cleanupRequest(request)
        else
            request.state = REQUEST_STATE.ERROR
            request.error = 'Header receive error: ' .. (err or 'unknown')
            cleanupRequest(request)
        end
    elseif request.state == REQUEST_STATE.RECEIVING_BODY then
        local done, err
        if request.isChunked then
            done, err = handleChunkedBody(request)
        else
            done, err = handlePlainBody(request)
        end

        if done == true then
            request.state = REQUEST_STATE.COMPLETE
            log(request, 'Body complete' .. (request.isChunked and ' (chunked)' or ''))
        elseif done == false then
            -- Waiting for more data
        else
            request.state = REQUEST_STATE.ERROR
            request.error = err or 'Body receive error'
            cleanupRequest(request)
        end
    end
end

-- Complete request and invoke callback
local function completeRequest(request)
    if request.state == REQUEST_STATE.COMPLETE then
        local body = table.concat(request.responseBody or {})
        log(request, 'Request done: ' .. #body .. ' bytes')
        cleanupRequest(request)
        pcall(request.callback, body, nil, request.statusCode)
    else
        log(request, 'Request failed: ' .. (request.error or 'Unknown error'))
        cleanupRequest(request)
        pcall(request.callback, nil, request.error or 'Unknown error', request.statusCode)
    end
end

-- Process all active requests (call from d3d_present)
function nonBlockingRequests.processAll()
    local toComplete = {}

    for id, request in pairs(activeRequests) do
        if request.state == REQUEST_STATE.COMPLETE or request.state == REQUEST_STATE.ERROR then
            table.insert(toComplete, id)
        else
            local success, err = pcall(processRequest, request)
            if not success then
                log(request, 'Processing error for request ' .. id .. ': ' .. tostring(err))
                request.state = REQUEST_STATE.ERROR
                request.error = 'Internal error: ' .. tostring(err)
                table.insert(toComplete, id)
            elseif request.state == REQUEST_STATE.COMPLETE or request.state == REQUEST_STATE.ERROR then
                table.insert(toComplete, id)
            end
        end
    end

    -- Complete finished requests
    for _, id in ipairs(toComplete) do
        local request = activeRequests[id]
        if request then
            completeRequest(request)
            activeRequests[id] = nil
        end
    end
end

local function enqueueRequest(method, url, headers, body, callback, options)
    if type(callback) ~= 'function' then
        error('Callback must be a function')
    end

    options = options or {}

    local request = {
        id = nextRequestId,
        url = url,
        method = method,
        headers = headers,
        body = body,
        callback = callback,
        state = REQUEST_STATE.INIT,
        debug = options.debug or false,
        headerLines = {},
        redirectCount = 0
    }

    activeRequests[nextRequestId] = request
    nextRequestId = nextRequestId + 1

    log(request, 'Queued request')
    return request.id
end

function nonBlockingRequests.get(url, headers, callback, options)
    return enqueueRequest('GET', url, headers, nil, callback, options)
end

function nonBlockingRequests.post(url, body, headers, callback, options)
    return enqueueRequest('POST', url, headers, body, callback, options)
end

function nonBlockingRequests.cancel(requestId)
    local request = activeRequests[requestId]
    if request then
        cleanupRequest(request)
        activeRequests[requestId] = nil
        log(request, 'Cancelled request')
        return true
    end
    return false
end

function nonBlockingRequests.getActiveCount()
    local count = 0
    for _ in pairs(activeRequests) do
        count = count + 1
    end
    return count
end

function nonBlockingRequests.setDebug(enabled)
    DEBUG = enabled and true or false
    log('Global debug ' .. (DEBUG and 'enabled' or 'disabled'), nil, true)
end

return nonBlockingRequests
