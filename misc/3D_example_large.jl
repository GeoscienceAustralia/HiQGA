using PyPlot, Random, TransD_GP, GP, Statistics

function geomprogdepth(n, dy, c)
    dy*(1.0-c^n)/(1-c)
end

function getn(z, dy, c)
    log(1 - z/dy*(1-c))/log(c)
end

function nicenup(g::PyPlot.Figure;fsize=16)
    for ax in gcf().axes
        ax.tick_params("both",labelsize=fsize)
        ax.xaxis.label.set_fontsize(fsize)
        ax.yaxis.label.set_fontsize(fsize)
        ax.title.set_fontsize(fsize)
        if typeof(ax.get_legend_handles_labels()[1]) != Array{Any,1}
            ax.legend(loc="best", fontsize=fsize)
        end
    end
    g.tight_layout()
end

    n, dz, extendfrac  = 20, 1.6, 1.245
    znrange            = 1.0:n
    zboundaries        = geomprogdepth.(znrange, dz, extendfrac)
    thickness          = [zboundaries[1]; diff(zboundaries)[1:end-1]]
    zall               = [zboundaries[1]/2; 0.5*(zboundaries[1:end-1] + zboundaries[2:end])]
    znall              = getn.(zall, dz, extendfrac)

    figure()
    plot(znall, zall)
    xlabel("depth index")
    ylabel("depth associated km")
    grid()
    nicenup(gcf())

    f, ax = plt.subplots(1, 2, figsize=(10,5))
    ax[1].stem(zboundaries[1:end-1], zboundaries[1:end-1], markerfmt="")
    ax[1].stem(zall, zall, "k--", markerfmt=" ")
    ax[1].set_xlabel("depth km")
    ax[1].set_ylabel("depth km")

    ax[2].stem(znrange[1:end-1], znrange[1:end-1], markerfmt="")
    ax[2].stem(znall, znall, "k--", markerfmt=" ")
    ax[2].set_ylabel("depth index")
    ax[2].set_xlabel("depth index")
    nicenup(gcf())

    f, ax = plt.subplots(1, 2, figsize=(10,5), sharey=true)
    ax[1].stem(zall[1:end-1],thickness, "k--", markerfmt=" ")
    ax[1].set_xlabel("depth km")
    ax[1].set_ylabel("thickness km")
    ax[1].yaxis.grid(which="major")
    ax[2].stem(znall[1:end-1],thickness, "k--", markerfmt=" ")
    ax[2].set_xlabel("depth index")
    ax[2].yaxis.grid(which="major")
    nicenup(f)

    nmin, nmax = 2, 200
    λ, δ = [150, 400, 1], 0.1
    fbounds = [-2.5 0.25]
    demean = true
    sdev_prop = 0.1
    sdev_pos = [8;8.0;1.4]
    pnorm = 2.

    λx,λy = 1600.0, 1600.0
    dx, dy = 0.025λx, 0.025λy
    x = 0:(dx):λx-dx
    y = 0:(dy):λy-dy
    xall = zeros(3,length(x)*length(y)*length(znall))
    for i in 1:size(xall,2)
        xid, yid, zid = Tuple(CartesianIndices((length(x),length(y),length(znall)))[i])
        xall[:,i] = [x[xid]; y[yid]; znall[zid]]
    end
    xbounds = zeros(Float64,size(xall,1),2)
    for dim in 1:size(xall, 1)
        xbounds[dim,:] = [minimum(xall[dim,:]), maximum(xall[dim,:])]
    end

## Initialize a model using these options
Random.seed!(4)
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
                        pnorm = pnorm,
                        quasimultid = false
                        )
@time m = TransD_GP.init(opt)
for i = 1:48 # 20 also works well if you switch off timebirth. Keep it on for an interesting model
    TransD_GP.birth!(m, opt, mdummy, optdummy)
end
timebirth = true
if timebirth
    ts = time(); ndo = 100
    for i = 1:ndo
        TransD_GP.birth!(m, opt, mdummy, optdummy)
        TransD_GP.death!(m, opt, mdummy, optdummy)
    end
    dt = time() - ts
    @info "avg time per move is $(dt/ndo/2)"
end

v = reshape(m.fstar,length(x), length(y), length(znall))
meshgrid(xs, ys) = [xs[i] for i in 1:length(xs), j in 1:length(ys)], [ys[j] for i in 1:length(xs), j in 1:length(ys)]
xx,yy = meshgrid(x,y)
f = figure(figsize=(10,10))
l = [9, 15, 18, 20]
for i in l
    c=(v[:,:,i].-minimum(v))./(maximum(v)-minimum(v))
    plot_surface(xx, yy, zall[i]*ones(size(yy)), facecolors=plt.cm.jet(c), shade=false, alpha=0.9)
end
scatter3D(m.xtrain[1,1:m.n], m.xtrain[2,1:m.n], geomprogdepth.(m.xtrain[3,1:m.n], dz, extendfrac), c=m.ftrain[1:m.n], vmin=minimum(v), vmax=maximum(v), s=50, cmap="jet", alpha=0.8)
xlabel("x km")
ylabel("y km")
zlabel("depth km")
cbar = f.colorbar(plt.cm.ScalarMappable(cmap="jet",norm=matplotlib.colors.Normalize(vmin=minimum(v), vmax=maximum(v))),ax=gca())
cbar.set_label(L"\log_{10} \sigma")
gca().zaxis.label.set_fontsize(13); nicenup(gcf(), fsize=13)
gca().invert_zaxis()

yy,zz = meshgrid(y,zall)
f = figure(figsize=(10,10))
l = [2, 10, 18, 26, 35]
for i in l
    c=(v[i,:,:].-minimum(v))./(maximum(v)-minimum(v))
    plot_surface(x[i]*ones(size(yy)), yy, zz, facecolors=plt.cm.jet(c), shade=false, alpha=0.9)
end
scatter3D(m.xtrain[1,1:m.n], m.xtrain[2,1:m.n], geomprogdepth.(m.xtrain[3,1:m.n], dz, extendfrac), c=m.ftrain[1:m.n], vmin=minimum(v), vmax=maximum(v), s=50, cmap="jet", alpha=0.8)
xlabel("x km")
ylabel("y km")
zlabel("depth km")
cbar = f.colorbar(plt.cm.ScalarMappable(cmap="jet",norm=matplotlib.colors.Normalize(vmin=minimum(v), vmax=maximum(v))),ax=gca())
cbar.set_label(L"\log_{10} \sigma")
gca().zaxis.label.set_fontsize(14); nicenup(gcf())
gca().invert_zaxis()