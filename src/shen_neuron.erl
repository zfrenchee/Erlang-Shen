-module (shen_neuron).
-export ([start/1]).


-define(INIT_EPSILON, 0.0001).


% LayerBefore and LayerAfter are PID lists. 
start(M) ->

	receive
		{NetworkPid, LayerBefore, LayerAfter} -> ok
	end,

	% random initialization of Thetas
	ThetaMap = maps:new(),
	lists:map(fun(Pid) -> maps:put(Pid, (random:uniform()*(2.0*?INIT_EPSILON))-?INIT_EPSILON, ThetaMap) end, LayerBefore),

	outerLoop(LayerBefore, LayerAfter, ThetaMap, M).


outerLoop(LayerBefore, LayerAfter, ThetaMap, M) ->

	% Initialize the Accumulator, accumulates error
	Accumulator = maps:new(),
	lists:map(fun(Pid) -> maps:put(Pid, 0, Accumulator) end, LayerAfter),

	% One iteration of training
	Accumulated = loop(LayerBefore, LayerAfter, ThetaMap, maps:new(), maps:new(), Accumulator, M).

	% Compute Partial Derivatives
	DMap = maps:new(),
	lists:map(fun(Pid) -> maps:put(Pid, (1/M) * maps:get(Pid, Accumulated) + Lambda * maps:get(Pid, ThetaMap), DMap), LayerAfter),
	maps:put(Bias, (1/M) * maps:get(Pid, Accumulated), DMap),

	% Update Weights
	NewThetaMap = maps:new(),
	lists:map(fun(Pid) -> maps:put(Pid, maps:get(Pid, ThetaMap) - Alpha * maps:get(Pid, DMap), NewThetaMap), LayerBefore)
	maps:put(Bias, maps:get(Bias, ThetaMap) - Alpha * maps:get(Bias, DMap), NewThetaMap)

	outerLoop(NewThetaMap).

	% send messages to first layer. 
	% receive from last layer. 
	% send actual to last layer. 
	% make sure backprop stops for first layer. 


loop(LayerBefore, LayerAfter, ThetaMap, ActivationMap, DeltaMap, Accumulator, M) ->
	receive
		{Pid, Activation} when lists:member(Pid, LayerBefore) ->
			maps:put(Pid, Activation, ActivationMap),
			if maps:size() =:= length(LayerBefore) ->
				forward(LayerBefore, LayerAfter, ActivationMap, ThetaMap),
				loop(LayerBefore, LayerAfter, ThetaMap, maps:new(), DeltaMap), Accumulator, M;
			true ->
				loop(LayerBefore, LayerAfter, ThetaMap, ActivationMap, DeltaMap, Accumulator, M)
			end;
		{Pid, Delta} when member(Pid, LayerAfter) ->
			maps:put(Pid, Delta, DeltaMap),
			if maps:size(DeltaMap) =:= length(LayerAfter) ->
				NewAccumulator = backprop(LayerBefore, LayerAfter, DeltaMap, ThetaMap, Accumulator),
				if M > 1 -> 
					loop(LayerBefore, LayerAfter, ThetaMap, ActivationMap, maps:new(), NewAccumulator, M-1);
				M =:= 1 -> NewAccumulator
			true -> 
				loop(LayerBefore, LayerAfter, ThetaMap, ActivationMap, DeltaMap, Accumulator, M)
			end
	end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

forward(LayerBefore, LayerAfter, ActivationMap, ThetaMap) ->
	LinearCombination = lists:sum(lists:map(fun(Pid) -> maps:get(Pid, ActivationMap) * maps:get(Pid, ThetaMap) end, LayerBefore)),
	Activation = g(LinearCombination + maps:get(Bias, ThetaMap))
	lists:map(fun(Pid) -> Pid ! {self(), Activation} end, LayerAfter),
	Activation. 


g(Z) -> 1/(1+math:exp(-Z)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

backprop(LayerBefore, LayerAfter, DeltaMap, ThetaMap, Accumulator) -> 
	
	Error = lists:sum(lists:map(fun(Pid) -> maps:get(Pid, DeltaMap) * maps:get(Pid, ThetaMap) end, LayerAfter)),
	Delta = Activation * (1- Activation) * Error,

	lists:map(fun(Pid) -> 
				Change = Activation * maps:get(Pid, DeltaMap),
				maps:put(Pid, maps:get(Pid, Accumulator) + Change, Accumulator)
			end,
		LayerAfter),

	lists:map(fun(Pid) -> Pid ! {self(), Delta} end, LayerBefore), 

	Accumulator.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% gradient checking?

