import Base.copy
import Base.==
import Random.randperm
include("MOKP.jl")
mutable struct solution
    val_objectif::Vector{Int64}
    sol::Vector{Int64}
    cout::Vector{Int64}
end

function copy(x::solution)
    return solution(copy(x.val_objectif), copy(x.sol), copy(x.cout))
end

function ==(x::solution, y::solution)
    return x.val_objectif == y.val_objectif && x.sol == y.sol && x.cout == y.cout
end
# C = [1 2 0 1; 1 1 1 2]
# A = [1 5 3 3; 5 1 1 6; 1 1 9 2]
# b = [5, 10, 10]
# test_pb = _bi01IP(C, A, b)
# ----------------------------------------------------------------
# Sélectionne les points pour former l'ensemble bornant primal
function kung(E::Array{solution,1}, EPrime::Array{solution,1})
    S = union(E, EPrime)
    sort!(S, by = x -> x.val_objectif[1])
    SN::Vector{solution} = []
    push!(SN, S[1])
    minYFeas = S[1].val_objectif[2]
    for i = 2:length(S)
        if S[i].val_objectif[2] < minYFeas
            push!(SN, S[i])
            minYFeas = S[i].val_objectif[2]
        end
    end
    return SN
end

function verification(prob::_bi01IP, x::solution)
    poids = zeros(size(prob.A, 1))
    objectif = [0, 0]
    for i = 1:size(prob.A, 1)
        for j = 1:size(prob.A, 2)
            poids[i] += prob.A[i, j] * x.sol[j]
        end
    end
    for i = 1:size(prob.C, 2)
        objectif[1] += prob.C[1, i] * x.sol[i]
        objectif[2] += prob.C[2, i] * x.sol[i]
    end
    if sum(poids .<= prob.b) == length(prob.b)
        x.val_objectif = -objectif
        x.cout = poids
        return true
    else
        return false
    end
end

function no_dominated(x::solution, E::Array{solution,1})
    # E must be sorted lexicographically to work
    pos = 0
    while pos + 1 <= length(E) && x.val_objectif[1] >= E[pos+1].val_objectif[1]
        pos += 1
    end
    if pos == 0
        return true
    elseif pos == length(E)
        return x.val_objectif[2] < E[pos].val_objectif[2]
    else
        x.val_objectif[2] == E[pos+1].val_objectif[2]
        return x.val_objectif[2] < E[pos].val_objectif[2]
    end
end

function improvement(E::Array{solution,1}, EPrime::Array{solution,1})
    sort!(E, by = x -> x.val_objectif[1])
    for element in EPrime
        if no_dominated(element, E)
            return true
        end
    end
    return false
end

function neighborhood_change(E::Array{solution,1}, EPrime::Array{solution,1}, k::Int)
    if improvement(E, EPrime)
        E = kung(E, EPrime)
        return E, 1
    end
    return E, k + 1
end

function swap(x::solution, k::Int, prob::_bi01IP)
    iter = 0
    xPrime = copy(x)
    while iter < k
        rand1 = rand(1:length(xPrime.sol))
        rand2 = rand(1:length(xPrime.sol))
        xPrime.sol[rand1], xPrime.sol[rand2] = xPrime.sol[rand2], xPrime.sol[rand1]
        if verification(prob, xPrime)
            iter += 1
        else
            xPrime.sol[rand1], xPrime.sol[rand2] = xPrime.sol[rand1], xPrime.sol[rand2]
        end
    end
    return xPrime
end

function replace(x::solution, k::Int, prob::_bi01IP)
    iter = 0
    xPrime = copy(x)
    while iter < k
        random_idx = rand(1:length(xPrime.sol))
        xPrime.sol[random_idx] = (xPrime.sol[random_idx] + 1) % 2
        if verification(prob, xPrime)
            iter += 1
        else
            xPrime.sol[random_idx] = (xPrime.sol[random_idx] + 1) % 2
        end
    end
    return xPrime
end

function shake(x::solution, k::Int, type_shake::Int, prob::_bi01IP)
    if type_shake == 1
        return swap(x, k, prob)
    elseif type_shake == 2
        return swap(x, k, prob)
    elseif type_shake == 3
        return swap(x, k, prob)
    elseif type_shake == 4
        return swap(x, k, prob)
    end
end

function mo_shake(E::Array{solution,1}, k::Int, type_shake::Int, prob::_bi01IP)
    EPrime::Vector{solution} = []
    for element in E
        xPrime = shake(element, k, type_shake, prob)
        push!(EPrime, xPrime)
    end
    return EPrime
end

function swap(x::solution, i::Int, j::Int)
    xPrime = copy(x)
    xPrime.sol[i], xPrime.sol[j] = xPrime.sol[j], xPrime.sol[i]
    return xPrime
end

function replace(x::solution, i::Int)
    xPrime = copy(x)
    xPrime.sol[i] = (1 + xPrime.sol[i]) % 2
    return xPrime
end

function voisinage_un_echange(x::solution, prob::_bi01IP)
    N::Vector{solution} = []
    push!(N, x)
    for i = 1:length(x.sol)
        for j = i+1:length(x.sol)
            xPrime = swap(x, i, j)
            if verification(prob, xPrime) && x != xPrime
                push!(N, xPrime)
            end
        end
    end
    return unique(x -> x.sol, N)
end

function voisinage_deux_echange(x::solution, prob::_bi01IP)
    N = []
    N_un_echange = voisinage_un_echange(x, prob)
    for xPrime in N_un_echange
        union!(N, voisinage_un_echange(xPrime, prob))
    end
    return unique(x -> x.sol, N)
end

function replace_neighborhood(x::solution, k::Int, prob::_bi01IP)
    N = []
    for i = 1:length(x.sol)
        xPrime = replace(x, i)
        if verification(prob, xPrime)
            push!(N, xPrime)
        end
    end
    if k != 1
        NPrime = []
        for xPrime in N
            union!(NPrime, replace_neighborhood(xPrime, k - 1, prob))
        end
        return unique(x -> x.sol, NPrime)
    else
        return unique(x -> x.sol, N)
    end
end

function swap_neighborhood(x::solution, k::Int, prob::_bi01IP)
    if k == 1
        return voisinage_un_echange(x, prob)
    end
    if k == 2
        return voisinage_deux_echange(x, prob)
    end
end

function VND_i(x::solution, kPrime_max::Int, i::Int, prob::_bi01IP)
    k = 1
    E::Vector{solution} = [x]
    xPrime = x
    while k < kPrime_max
        N::Vector{solution} = union(replace_neighborhood(x, k, prob), swap_neighborhood(x, k, prob))
        zPrime = minimum(x -> x.val_objectif[i], N)
        for element in N
            if element.val_objectif[i] == zPrime
                xPrime = element
                break
            end
        end
        E = kung(E, N)
        if xPrime.val_objectif[i] < x.val_objectif[i]
            x = xPrime
            k = 1
        else
            k += 1
        end
    end
    return E
end

function VND(E::Array{solution,1}, kPrime_max::Int, r::Int, prob::_bi01IP)
    # r = nombre d'objectifs
    S::Vector{Vector{solution}} = fill([], r)
    i = 1
    exclusion::Vector{solution} = setdiff(E, S[i])
    while i <= r
        while length(exclusion) > 0
            random = rand((1:length(exclusion)))
            xPrime = exclusion[random]
            Ei = VND_i(xPrime, kPrime_max, i, prob)
            union!(S[i], Ei)
            push!(S[i], xPrime)
            exclusion = setdiff(E, S[i])
        end
        E, i = neighborhood_change(E, S[i], i)
    end
    return E
end

function GVNS(E::Array{solution,1}, k_max::Int, t_max::Int, type_shake::Int, prob::_bi01IP, r = 2, kPrime_max = 2)
    t = 0.0
    start = time()
    while t < t_max
        k = 1
        while k <= k_max && t < t_max
            EPrime = mo_shake(E, k, type_shake, prob)
            ESecond = VND(EPrime, kPrime_max, r, prob)
            E, k = neighborhood_change(E, ESecond, k)
            t = time() - start
        end
    end
    println("time used : ", t)
    return E
end

function initPop(nIndiv::Int, prob::_bi01IP)
    population::Vector{solution} = []
    for i = 1:nIndiv
        sol::solution = solution([], zeros(size(prob.C, 2)), [])
        rand_indexes = randperm(length(sol.sol))
        idx = 1
        while verification(prob, sol)
            sol.sol[rand_indexes[idx]] = 1
            idx += 1
        end
        push!(population, sol)
    end
    return sort(population, by = x -> x.val_objectif)
end