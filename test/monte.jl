using DiffEqMonteCarlo, StochasticDiffEq, DiffEqBase,
      DiffEqProblemLibrary, OrdinaryDiffEq
using Test, Random, Statistics

using DiffEqProblemLibrary.SDEProblemLibrary: importsdeproblems; importsdeproblems()
import DiffEqProblemLibrary.SDEProblemLibrary: prob_sde_2Dlinear,
       prob_sde_additivesystem, prob_sde_lorenz
using DiffEqProblemLibrary.ODEProblemLibrary: importodeproblems; importodeproblems()
import DiffEqProblemLibrary.ODEProblemLibrary: prob_ode_linear

prob = prob_sde_2Dlinear
prob2 = MonteCarloProblem(prob)
sim = solve(prob2,SRIW1(),dt=1//2^(3),num_monte=10)
sim = solve(prob2,SRIW1(),dt=1//2^(3),num_monte=10,parallel_type=:threads)
sim = solve(prob2,SRIW1(),DiffEqMonteCarlo.MonteThreads(),dt=1//2^(3),num_monte=10)
err_sim = DiffEqBase.calculate_monte_errors(sim;weak_dense_errors=true)
@test length(sim) == 10

sim = solve(prob2,SRIW1(),DiffEqMonteCarlo.MonteThreads(),dt=1//2^(3),adaptive=false,num_monte=10)
err_sim = DiffEqBase.calculate_monte_errors(sim;weak_timeseries_errors=true)

sim = solve(prob2,SRIW1(),DiffEqMonteCarlo.MonteThreads(),dt=1//2^(3),num_monte=10)
DiffEqBase.calculate_monte_errors(sim)
@test length(sim) == 10

sim = solve(prob2,SRIW1(),DiffEqMonteCarlo.MonteSplitThreads(),dt=1//2^(3),num_monte=10)
DiffEqBase.calculate_monte_errors(sim)
@test length(sim) == 10

sim = solve(prob2,SRIW1(),DiffEqMonteCarlo.MonteSerial(),dt=1//2^(3),num_monte=10)
DiffEqBase.calculate_monte_errors(sim)
@test length(sim) == 10

prob = prob_sde_additivesystem
prob2 = MonteCarloProblem(prob)
sim = solve(prob2,SRA1(),dt=1//2^(3),num_monte=10)
DiffEqBase.calculate_monte_errors(sim)

output_func = function (sol,i)
  last(last(sol))^2,false
end
prob2 = MonteCarloProblem(prob,output_func=output_func)
sim = solve(prob2,SRA1(),dt=1//2^(3),num_monte=10)

prob = prob_sde_lorenz
prob2 = MonteCarloProblem(prob)
sim = solve(prob2,SRIW1(),dt=1//2^(3),num_monte=10)

output_func = function (sol,i)
  last(sol),false
end

prob = prob_ode_linear
prob_func = function (prob,i,repeat)
  ODEProblem(prob.f,rand()*prob.u0,prob.tspan,1.01)
end


Random.seed!(100)
reduction = function (u,batch,I)
  u = append!(u,batch)
  u,((var(u)/sqrt(last(I)))/mean(u)<0.5) ? true : false
end

prob2 = MonteCarloProblem(prob,prob_func=prob_func,output_func=output_func,reduction=reduction,u_init=Vector{Float64}())
sim = solve(prob2,Tsit5(),num_monte=10000,batch_size=20)
@test sim.converged == true


Random.seed!(100)
reduction = function (u,batch,I)
  u = append!(u,batch)
  u,false
end

prob2 = MonteCarloProblem(prob,prob_func=prob_func,output_func=output_func,reduction=reduction,u_init=Vector{Float64}())
sim = solve(prob2,Tsit5(),num_monte=100,batch_size=20)
@test sim.converged == false

Random.seed!(100)
reduction = function (u,batch,I)
  u+sum(batch),false
end
prob2 = MonteCarloProblem(prob,prob_func=prob_func,output_func=output_func,reduction=reduction,u_init=0.0)
sim2 = solve(prob2,Tsit5(),num_monte=100,batch_size=20)
@test sim2.converged == false
@test mean(sim.u) ≈ sim2.u/100

struct SomeUserType end
output_func = function (sol,i)
    (SomeUserType(),false)
end
prob2 = MonteCarloProblem(prob,prob_func=prob_func,output_func=output_func)
sim2 = solve(prob2,Tsit5(),num_monte=2)
@test !sim2.converged && typeof(sim2.u) == Vector{SomeUserType}
