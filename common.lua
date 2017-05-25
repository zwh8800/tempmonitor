function await(func)
    return function(...)
        local co

        local arg = {...}
        local len = select('#', ...) + 1
        arg[len] = function(...)
            if co == nil then
                co = {...}
            else
                coroutine.resume(co, ...)
            end
        end

        func(unpack(arg, 1, len))

        if co then
            return unpack(co)
        end

        co = coroutine.running()
        return coroutine.yield()
    end
end

function bind(func, ...)
    local upper_args = {...}
    return function(...) 
        func(unpack(upper_args), ...)
    end
end
