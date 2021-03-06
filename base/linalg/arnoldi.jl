# This file is a part of Julia. License is MIT: http://julialang.org/license

using .ARPACK

## eigs
"""
    eigs(A; nev=6, ncv=max(20,2*nev+1), which="LM", tol=0.0, maxiter=300, sigma=nothing, ritzvec=true, v0=zeros((0,))) -> (d,[v,],nconv,niter,nmult,resid)

Computes eigenvalues `d` of `A` using implicitly restarted Lanczos or Arnoldi iterations for real symmetric or
general nonsymmetric matrices respectively.

The following keyword arguments are supported:

* `nev`: Number of eigenvalues
* `ncv`: Number of Krylov vectors used in the computation; should satisfy `nev+1 <= ncv <= n`
  for real symmetric problems and `nev+2 <= ncv <= n` for other problems, where `n` is the
  size of the input matrix `A`. The default is `ncv = max(20,2*nev+1)`. Note that these
  restrictions limit the input matrix `A` to be of dimension at least 2.
* `which`: type of eigenvalues to compute. See the note below.

| `which` | type of eigenvalues                                                                                                       |
|:--------|:--------------------------------------------------------------------------------------------------------------------------|
| `:LM`   | eigenvalues of largest magnitude (default)                                                                                |
| `:SM`   | eigenvalues of smallest magnitude                                                                                         |
| `:LR`   | eigenvalues of largest real part                                                                                          |
| `:SR`   | eigenvalues of smallest real part                                                                                         |
| `:LI`   | eigenvalues of largest imaginary part (nonsymmetric or complex `A` only)                                                  |
| `:SI`   | eigenvalues of smallest imaginary part (nonsymmetric or complex `A` only)                                                 |
| `:BE`   | compute half of the eigenvalues from each end of the spectrum, biased in favor of the high end. (real symmetric `A` only) |

* `tol`: parameter defining the relative tolerance for convergence of Ritz values (eigenvalue estimates).
     A Ritz value ``θ`` is considered converged when its associated residual
     is less than or equal to the product of `tol` and ``max(ɛ^{2/3}, |θ|)``,
     where `ɛ = eps(real(eltype(A)))/2` is LAPACK's machine epsilon.
     The residual associated with ``θ`` and its corresponding Ritz vector ``v``
     is defined as the norm ``||Av - vθ||``.
     The specified value of `tol` should be positive; otherwise, it is ignored
     and ``ɛ`` is used instead.
     Default: ``ɛ``.

* `maxiter`: Maximum number of iterations (default = 300)
* `sigma`: Specifies the level shift used in inverse iteration. If `nothing` (default),
  defaults to ordinary (forward) iterations. Otherwise, find eigenvalues close to `sigma`
  using shift and invert iterations.
* `ritzvec`: Returns the Ritz vectors `v` (eigenvectors) if `true`
* `v0`: starting vector from which to start the iterations

`eigs` returns the `nev` requested eigenvalues in `d`, the corresponding Ritz vectors `v`
(only if `ritzvec=true`), the number of converged eigenvalues `nconv`, the number of
iterations `niter` and the number of matrix vector multiplications `nmult`, as well as the
final residual vector `resid`.

**note**

The `sigma` and `which` keywords interact: the description of eigenvalues searched for by
`which` do _not_ necessarily refer to the eigenvalues of `A`, but rather the linear operator
constructed by the specification of the iteration mode implied by `sigma`.

| `sigma`         | iteration mode                   | `which` refers to eigenvalues of |
|:----------------|:---------------------------------|:---------------------------------|
| `nothing`       | ordinary (forward)               | ``A``                            |
| real or complex | inverse with level shift `sigma` | ``(A - \\sigma I )^{-1}``        |

**note**

Although `tol` has a default value, the best choice depends strongly on the
matrix `A`. We recommend that users _always_ specify a value for `tol` which
suits their specific needs.

For details of how the errors in the computed eigenvalues are estimated, see:

* B. N. Parlett, "The Symmetric Eigenvalue Problem", SIAM: Philadelphia, 2/e
  (1998), Ch. 13.2, "Accessing Accuracy in Lanczos Problems", pp. 290-292 ff.
* R. B. Lehoucq and D. C. Sorensen, "Deflation Techniques for an Implicitly
  Restarted Arnoldi Iteration", SIAM Journal on Matrix Analysis and
  Applications (1996), 17(4), 789–821.  doi:10.1137/S0895479895281484
"""
eigs(A; kwargs...) = eigs(A, I; kwargs...)
eigs{T<:BlasFloat}(A::AbstractMatrix{T}, ::UniformScaling; kwargs...) = _eigs(A, I; kwargs...)

eigs{T<:BlasFloat}(A::AbstractMatrix{T}, B::AbstractMatrix{T}; kwargs...) = _eigs(A, B; kwargs...)
eigs(A::AbstractMatrix{BigFloat}, B::AbstractMatrix...; kwargs...) = throw(MethodError(eigs, Any[A,B,kwargs...]))
eigs(A::AbstractMatrix{BigFloat}, B::UniformScaling; kwargs...) = throw(MethodError(eigs, Any[A,B,kwargs...]))
function eigs{T}(A::AbstractMatrix{T}, ::UniformScaling; kwargs...)
    Tnew = typeof(zero(T)/sqrt(one(T)))
    eigs(convert(AbstractMatrix{Tnew}, A), I; kwargs...)
end
function eigs(A::AbstractMatrix, B::AbstractMatrix; kwargs...)
    T = promote_type(eltype(A), eltype(B))
    Tnew = typeof(zero(T)/sqrt(one(T)))
    eigs(convert(AbstractMatrix{Tnew}, A), convert(AbstractMatrix{Tnew}, B); kwargs...)
end
"""
    eigs(A, B; nev=6, ncv=max(20,2*nev+1), which="LM", tol=0.0, maxiter=300, sigma=nothing, ritzvec=true, v0=zeros((0,))) -> (d,[v,],nconv,niter,nmult,resid)

Computes generalized eigenvalues `d` of `A` and `B` using implicitly restarted Lanczos or Arnoldi iterations for
real symmetric or general nonsymmetric matrices respectively.

The following keyword arguments are supported:

* `nev`: Number of eigenvalues
* `ncv`: Number of Krylov vectors used in the computation; should satisfy `nev+1 <= ncv <= n`
  for real symmetric problems and `nev+2 <= ncv <= n` for other problems, where `n` is the
  size of the input matrices `A` and `B`. The default is `ncv = max(20,2*nev+1)`. Note that
  these restrictions limit the input matrix `A` to be of dimension at least 2.
* `which`: type of eigenvalues to compute. See the note below.

| `which` | type of eigenvalues                                                                                                       |
|:--------|:--------------------------------------------------------------------------------------------------------------------------|
| `:LM`   | eigenvalues of largest magnitude (default)                                                                                |
| `:SM`   | eigenvalues of smallest magnitude                                                                                         |
| `:LR`   | eigenvalues of largest real part                                                                                          |
| `:SR`   | eigenvalues of smallest real part                                                                                         |
| `:LI`   | eigenvalues of largest imaginary part (nonsymmetric or complex `A` only)                                                  |
| `:SI`   | eigenvalues of smallest imaginary part (nonsymmetric or complex `A` only)                                                 |
| `:BE`   | compute half of the eigenvalues from each end of the spectrum, biased in favor of the high end. (real symmetric `A` only) |

* `tol`: relative tolerance used in the convergence criterion for eigenvalues, similar to
     `tol` in the [`eigs(A)`](:func:`eigs`) method for the ordinary eigenvalue
     problem, but effectively for the eigenvalues of ``B^{-1} A`` instead of ``A``.
     See the documentation for the ordinary eigenvalue problem in
     [`eigs(A)`](:func:`eigs`) and the accompanying note about `tol`.
* `maxiter`: Maximum number of iterations (default = 300)
* `sigma`: Specifies the level shift used in inverse iteration. If `nothing` (default),
  defaults to ordinary (forward) iterations. Otherwise, find eigenvalues close to `sigma`
  using shift and invert iterations.
* `ritzvec`: Returns the Ritz vectors `v` (eigenvectors) if `true`
* `v0`: starting vector from which to start the iterations

`eigs` returns the `nev` requested eigenvalues in `d`, the corresponding Ritz vectors `v`
(only if `ritzvec=true`), the number of converged eigenvalues `nconv`, the number of
iterations `niter` and the number of matrix vector multiplications `nmult`, as well as the
final residual vector `resid`.

**note**

The `sigma` and `which` keywords interact: the description of eigenvalues searched for by
`which` do _not_ necessarily refer to the eigenvalue problem ``Av = Bv\\lambda``, but rather
the linear operator constructed by the specification of the iteration mode implied by `sigma`.

| `sigma`         | iteration mode                   | `which` refers to the problem      |
|:----------------|:---------------------------------|:-----------------------------------|
| `nothing`       | ordinary (forward)               | ``Av = Bv\\lambda``                |
| real or complex | inverse with level shift `sigma` | ``(A - \\sigma B )^{-1}B = v\\nu`` |
"""
eigs(A, B; kwargs...) = _eigs(A, B; kwargs...)
function _eigs(A, B;
              nev::Integer=6, ncv::Integer=max(20,2*nev+1), which=:LM,
              tol=0.0, maxiter::Integer=300, sigma=nothing, v0::Vector=zeros(eltype(A),(0,)),
              ritzvec::Bool=true)

    n = checksquare(A)

    T = eltype(A)
    iscmplx = T <: Complex
    isgeneral = B !== I
    sym = issymmetric(A) && !iscmplx
    nevmax=sym ? n-1 : n-2
    if nevmax <= 0
        throw(ArgumentError("Input matrix A is too small. Use eigfact instead."))
    end
    if nev > nevmax
        warn("Adjusting nev from $nev to $nevmax")
        nev = nevmax
    end
    if nev <= 0
        throw(ArgumentError("requested number of eigenvalues (nev) must be ≥ 1, got $nev"))
    end
    ncvmin = nev + (sym ? 1 : 2)
    if ncv < ncvmin
        warn("Adjusting ncv from $ncv to $ncvmin")
        ncv = ncvmin
    end
    ncv = BlasInt(min(ncv, n))
    if isgeneral && !isposdef(B)
        throw(PosDefException(0))
    end
    bmat = isgeneral ? "G" : "I"
    isshift = sigma !== nothing

    if isa(which,AbstractString)
        warn("Use symbols instead of strings for specifying which eigenvalues to compute")
        which=symbol(which)
    end
    if (which != :LM && which != :SM && which != :LR && which != :SR &&
        which != :LI && which != :SI && which != :BE)
        throw(ArgumentError("which must be :LM, :SM, :LR, :SR, :LI, :SI, or :BE, got $(repr(which))"))
    end
    if which == :BE && !sym
        throw(ArgumentError("which=:BE only possible for real symmetric problem"))
    end
    isshift && which == :SM && warn("use of :SM in shift-and-invert mode is not recommended, use :LM to find eigenvalues closest to sigma")

    if which==:SM && !isshift # transform into shift-and-invert method with sigma = 0
        isshift=true
        sigma=zero(T)
        which=:LM
    end

    if sigma !== nothing && !iscmplx && isa(sigma,Complex)
        throw(ArgumentError("complex shifts for real problems are not yet supported"))
    end
    sigma = isshift ? convert(T,sigma) : zero(T)

    if !isempty(v0)
        if length(v0) != n
            throw(DimensionMismatch())
        end
        if eltype(v0) != T
            throw(ArgumentError("starting vector must have element type $T, got $(eltype(v0))"))
        end
    end

    whichstr = "LM"
    if which == :BE
        whichstr = "BE"
    end
    if which == :LR
        whichstr = (!sym ? "LR" : "LA")
    end
    if which == :SR
        whichstr = (!sym ? "SR" : "SA")
    end
    if which == :LI
        if !sym
            whichstr = "LI"
        else
            throw(ArgumentError("largest imaginary is meaningless for symmetric eigenvalue problems"))
        end
    end
    if which == :SI
        if !sym
            whichstr = "SI"
        else
            throw(ArgumentError("smallest imaginary is meaningless for symmetric eigenvalue problems"))
        end
    end

    # Refer to ex-*.doc files in ARPACK/DOCUMENTS for calling sequence
    matvecA(x) = A * x
    if !isgeneral           # Standard problem
        matvecB = x -> x
        if !isshift         #    Regular mode
            mode       = 1
            solveSI = x->x
        else                #    Shift-invert mode
            mode       = 3
            F = factorize(sigma==zero(T) ? A : A - UniformScaling(sigma))
            solveSI = x -> F \ x
        end
    else                    # Generalized eigenproblem
        matvecB = x -> B * x
        if !isshift         #    Regular inverse mode
            mode       = 2
            F = factorize(B)
            solveSI = x -> F \ x
        else                #    Shift-invert mode
            mode       = 3
            F = factorize(sigma==zero(T) ? A : A-sigma*B)
            solveSI = x -> F \ x
        end
    end

    # Compute the Ritz values and Ritz vectors
    (resid, v, ldv, iparam, ipntr, workd, workl, lworkl, rwork, TOL) =
       ARPACK.aupd_wrapper(T, matvecA, matvecB, solveSI, n, sym, iscmplx, bmat, nev, ncv, whichstr, tol, maxiter, mode, v0)

    # Postprocessing to get eigenvalues and eigenvectors
    output = ARPACK.eupd_wrapper(T, n, sym, iscmplx, bmat, nev, whichstr, ritzvec, TOL,
                                 resid, ncv, v, ldv, sigma, iparam, ipntr, workd, workl, lworkl, rwork)

    # Issue 10495, 10701: Check that all eigenvalues are converged
    nev = length(output[1])
    nconv = output[ritzvec ? 3 : 2]
    nev ≤ nconv || warn("not all wanted Ritz pairs converged. Requested: $nev, converged: $nconv")

    return output
end


## svds
### Restrict operator to BlasFloat because ARPACK only supports that. Loosen restriction
### when we switch to our own implementation
type SVDOperator{T<:BlasFloat,S} <: AbstractArray{T, 2}
    X::S
    m::Int
    n::Int
    SVDOperator(X::AbstractMatrix) = new(X, size(X, 1), size(X, 2))
end

function SVDOperator{T}(A::AbstractMatrix{T})
    Tnew = typeof(zero(T)/sqrt(one(T)))
    Anew = convert(AbstractMatrix{Tnew}, A)
    SVDOperator{Tnew,typeof(Anew)}(Anew)
end

## v = [ left_singular_vector; right_singular_vector ]
*{T,S}(s::SVDOperator{T,S}, v::Vector{T}) = [s.X * v[s.m+1:end]; s.X' * v[1:s.m]]
size(s::SVDOperator)  = s.m + s.n, s.m + s.n
issymmetric(s::SVDOperator) = true

svds{T<:BlasFloat}(A::AbstractMatrix{T}; kwargs...) = _svds(A; kwargs...)
svds(A::AbstractMatrix{BigFloat}; kwargs...) = throw(MethodError(svds, Any[A, kwargs...]))
function svds{T}(A::AbstractMatrix{T}; kwargs...)
    Tnew = typeof(zero(T)/sqrt(one(T)))
    svds(convert(AbstractMatrix{Tnew}, A); kwargs...)
end

"""
    svds(A; nsv=6, ritzvec=true, tol=0.0, maxiter=1000) -> ([left_sv,] s, [right_sv,] nconv, niter, nmult, resid)

Computes the largest singular values `s` of `A` using implicitly restarted Lanczos
iterations derived from [`eigs`](:func:`eigs`).

**Inputs**

* `A`: Linear operator whose singular values are desired. `A` may be represented
  as a subtype of `AbstractArray`, e.g., a sparse matrix, or any other type
  supporting the four methods `size(A)`, `eltype(A)`, `A * vector`, and
  `A' * vector`.
* `nsv`: Number of singular values.
* `ritzvec`: If `true`, return the left and right singular vectors `left_sv` and `right_sv`.
   If `false`, omit the singular vectors. Default: `true`.
* `tol`: tolerance, see [`eigs`](:func:`eigs`).
* `maxiter`: Maximum number of iterations, see [`eigs`](:func:`eigs`).

**Outputs**

* `left_sv`: Left singular vectors (only if `ritzvec = true`).
* `s`: A vector of length `nsv` containing the requested singular values.
* `right_sv`: Right singular vectors (only if `ritzvec = true`).
* `nconv`: Number of converged singular values.
* `niter`: Number of iterations.
* `nmult`: Number of matrix--vector products used.
* `resid`: Final residual vector.

**Example**

```julia
X = sprand(10, 5, 0.2)
svds(X, nsv = 2)
```

**Implementation note**

`svds(A)` is formally equivalent to calling `eigs` to perform implicitly restarted
Lanczos tridiagonalization on the Hermitian matrix
``\\begin{pmatrix} 0 & A^\\prime \\\\ A & 0 \\end{pmatrix}``, whose eigenvalues are
plus and minus the singular values of ``A``.
"""
svds(A; kwargs...) = _svds(A; kwargs...)
function _svds(X; nsv::Int = 6, ritzvec::Bool = true, tol::Float64 = 0.0, maxiter::Int = 1000)
    if nsv < 1
        throw(ArgumentError("number of singular values (nsv) must be ≥ 1, got $nsv"))
    end
    if nsv > minimum(size(X))
        throw(ArgumentError("number of singular values (nsv) must be ≤ $(minimum(size(X))), got $nsv"))
    end
    otype = eltype(X)
    ex    = eigs(SVDOperator(X), I; ritzvec = ritzvec, nev = 2*nsv, tol = tol, maxiter = maxiter)
    ind   = [1:2:nsv*2;]
    sval  = abs(ex[1][ind])

    #The sort is necessary to work around #10329
    ritzvec || return (sort!(sval, by=real, rev=true), ex[2], ex[3], ex[4], ex[5])

    # calculating singular vectors
    left_sv  = sqrt(2) * ex[2][ 1:size(X,1),     ind ] .* sign(ex[1][ind]')
    right_sv = sqrt(2) * ex[2][ size(X,1)+1:end, ind ]
    return (left_sv, sval, right_sv, ex[3], ex[4], ex[5], ex[6])
end
