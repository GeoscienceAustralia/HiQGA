Sys.iswindows() && (ENV["MPLBACKEND"]="qt4agg")
using PyPlot, Test, Random, Revise, Statistics, LinearAlgebra
any(pwd() .== LOAD_PATH) || push!(LOAD_PATH, pwd())
import GP, TransD_GP
## make options for the model we'll be modifying in McMC
nmin, nmax = 2, 400
λ, δ = [0.1, 0.05], 0.1
fbounds = [-2 2.]
demean = true
sdev_prop = 0.1
sdev_pos = [0.05;0.05]
pnorm = 2.

λx,λy = 0.6,0.6
x = 0:(0.01λx):λx
y = 0:(0.01λy):2λy
xall = zeros(2,length(x)*length(y))
for i in 1:size(xall,2)
    yid, xid = Tuple(CartesianIndices((length(y),length(x)))[i])
    xall[:,i] = [x[xid]; y[yid]]
end
xbounds = zeros(Float64,ndims(xall),2)
for dim in 1:ndims(xall)
    xbounds[dim,:] = [minimum(xall[dim,:]), maximum(xall[dim,:])]
end
## Initialize a model using these options
Random.seed!(12)
opt = TransD_GP.Options(nmin = nmin,
                        nmax = nmax,
                        xbounds = xbounds,
                        fbounds = fbounds,
                        xall = xall,
                        λ = λ,
                        δ = δ,
                        demean = demean,
                        sdev_prop = sdev_prop,
                        sdev_pos = sdev_pos,
                        pnorm = pnorm
                        )
@time m = TransD_GP.init(opt)
## run tests for the different McMC moves
@testset "GP and MCMC move do and undo state tests" begin
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(mean(ftest - m.fstar)) < 1e-12
    for i = 1:100
        TransD_GP.birth!(m, opt)
    end
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(ftest - m.fstar) < 1e-12
    for i = 1:100
        TransD_GP.death!(m, opt)
    end
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(mean(ftest - m.fstar)) < 1e-12
    # birth and death hold correct states if tests above passed
    mold = deepcopy(m)
    TransD_GP.birth!(m, opt)
    TransD_GP.undo_birth!(m, opt)
    TransD_GP.sync_model!(m, opt)
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(ftest - m.fstar) < 1e-12
    @test norm(mean(mold.fstar - m.fstar)) < 1e-12
    # undo_birth holds state if gotten till here
    TransD_GP.birth!(m, opt)
    TransD_GP.birth!(m, opt)
    mold = deepcopy(m)
    TransD_GP.birth!(m, opt)
    TransD_GP.undo_birth!(m, opt)
    TransD_GP.sync_model!(m, opt)
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(ftest - m.fstar) < 1e-12
    @test norm(mean(mold.fstar - m.fstar)) < 1e-12
    # undo_birth holds state as well for multiple births and deaths till here
    mold = deepcopy(m)
    TransD_GP.death!(m, opt)
    TransD_GP.undo_death!(m, opt)
    TransD_GP.sync_model!(m, opt)
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(ftest - m.fstar) < 1e-12
    @test norm(mean(mold.fstar - m.fstar)) < 1e-12
    # undo death holds state if here
    TransD_GP.birth!(m, opt)
    TransD_GP.birth!(m, opt)
    TransD_GP.birth!(m, opt)
    mold = deepcopy(m)
    TransD_GP.death!(m, opt)
    TransD_GP.undo_death!(m, opt)
    TransD_GP.sync_model!(m, opt)
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(ftest - m.fstar) < 1e-12
    @test norm(mean(mold.fstar - m.fstar)) < 1e-12
    # undo_death holds state as well for multiple births and deaths till here
    TransD_GP.property_change!(m, opt)
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(mean(ftest - m.fstar)) < 1e-12
    # property change works if here
    mold = deepcopy(m)
    TransD_GP.property_change!(m, opt)
    TransD_GP.undo_property_change!(m, opt)
    TransD_GP.sync_model!(m, opt)
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(ftest - m.fstar) < 1e-12
    @test norm(mean(mold.fstar - m.fstar)) < 1e-12
    # undo property change works if here
    TransD_GP.position_change!(m, opt)
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(mean(ftest - m.fstar)) < 1e-12
    # position change works if here
    mold = deepcopy(m)
    TransD_GP.position_change!(m, opt)
    TransD_GP.undo_position_change!(m, opt)
    TransD_GP.sync_model!(m, opt)
    ftest = GP.GPfit(m.ftrain[1:m.n], m.xtrain[:,1:m.n], opt.xall, opt.λ, opt.δ, nogetvars=true, demean=demean, p=pnorm)[1]
    @test norm(ftest - m.fstar) < 1e-12
    @test norm(mean(mold.fstar - m.fstar)) < 1e-12
    # undo position change works if here
    @time for i = 1:300
              TransD_GP.birth!(m, opt)
    end
    figure()
    imshow(reshape(m.fstar,length(y), length(x)), extent=[x[1],x[end],y[end],y[1]]); colorbar()
    scatter(m.xtrain[1,1:m.n], m.xtrain[2,1:m.n],marker="+",c="r")
    scatter(m.xtrain[1,1:m.n], m.xtrain[2,1:m.n],c=m.ftrain[1:m.n], alpha=0.8)
    clim(minimum(m.fstar), maximum(m.fstar))
end