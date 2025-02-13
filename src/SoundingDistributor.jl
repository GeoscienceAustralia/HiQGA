module SoundingDistributor
using Distributed
export splittasks, getss, getpids, writetogloballog, catlocallogs, getss_deterministic

function splittasks(soundings::AbstractVector; nchainspersounding=nothing, ppn=nothing, fname="")
    nsoundings = length(soundings)
    ncores = nworkers()
    splittasks(;nsoundings, ncores, nchainspersounding, ppn, fname)
end

function splittasks(;nsoundings=nothing, ncores=nothing, nchainspersounding=nothing, ppn=nothing, fname="")
    # split into sequential iterations of parallel soundings
    @assert !any(isnothing.([nsoundings, ncores, nchainspersounding, ppn]))
    @assert mod(ppn, nchainspersounding+1) == 0
    # global manager does no work, ever, safest
    subtractone = 1
    nparallelsoundings = Int((ncores+1)/(nchainspersounding+1)) - subtractone
    nsequentialiters = ceil(Int, nsoundings/nparallelsoundings)
    str = "will require $nsequentialiters iterations of $nparallelsoundings soundings in one iteration"
    if isempty(fname)
        @info str
    else
        writetogloballog(str; iomode="w", fname)
    end
    nsequentialiters, nparallelsoundings
end    

function getss(iter, nsequentialiters, nparallelsoundings, nsoundings)
    if iter<nsequentialiters
        ss = (iter-1)*nparallelsoundings+1:iter*nparallelsoundings
    else
        ss = (iter-1)*nparallelsoundings+1:nsoundings
    end
    ss
end

function getss_deterministic(iter, nsequentialiters, nparallelsoundings, nsoundings)
    if iter<nsequentialiters
        ss = (iter-1)*nparallelsoundings+1:iter*nparallelsoundings
    else
        ss = (iter-1)*nparallelsoundings+1:nsoundings
    end
end

function getpids(i, nchainspersounding)
    pids = reverse((nprocs()+2) .- (i*(nchainspersounding+1)+1:(i+1)*(nchainspersounding+1)))
end

# Global logging function
function writetogloballog(str::String; fname="global.log", iomode="a", newline=true)
    io = open(fname, iomode)
    nwchar = newline ? "\n" : ""
    write(io, str*nwchar)
    flush(io)
    close(io)
end

function catlocallogs(nparallelsoundings, nchainspersounding, batchstr::String)
    managerpids = [p[1] for p in getpids.(1:nparallelsoundings, nchainspersounding)]
    map(managerpids) do p
        locallogfile = batchstr*"_$p.log"
        if isfile(locallogfile)
            writetogloballog(read(locallogfile, String); newline=false, fname = batchstr*"_global.log" )
            rm(locallogfile)
        end
    end
end

end
