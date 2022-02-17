function debug(line::String, sev::Int = 1)
    #uncomment to turn off
    return
    #uncomment & edit to have low sev off
    #(sev<0) && return
    println("[$(StackTraces.stacktrace()[3].func)] $line")
end

function debug(item::Any, sev::Int = 1)
    debug(string(item), sev)
end
