
% test row
row([1,0,0,0,0,0,-1,6]).

/* testing function */
t :-
    % generateRandomBoard(B, [Digits, Rows, Cols]),
    reset_timer,
    exampleBoard3(B, [Digits, Rows, Cols]),
    printMatrix(B),
    write('Solving...'),nl,
    length(Solution, Digits),

    % Calc domain
    calcRowDomain(B, 0, Cols, [], RowListDomain),
    transpose(B, TB),
    calcColDomain(TB, 0, Cols,Rows, [], ColListDomain),

    % printMatrix(TB),
    list_to_fdset(RowListDomain, RowDomainSet),
    list_to_fdset(ColListDomain, ColDomainSet),
    fdset_intersection(RowDomainSet, ColDomainSet, DomainSet),
    applyDomain(Solution, DomainSet),
    all_distinct(Solution),

    % placing constraints
    constrainPlacing(Solution, Cols, Rows, B),
    addSolution(Solution, 1, Cols, B, FinalBoard),
    % torque constraints
    torqueConstraint(FinalBoard),

    % write('Transposing...\n'),
    transpose(FinalBoard, TFBoard),
    torqueConstraint(TFBoard),
    labeling([], Solution),
    print_time,
    fd_statistics,
    write(Solution),nl,
    printMatrix(FinalBoard).

calcRowDomain([], _, _, FinalList, FinalList).
calcRowDomain([H|T], Row, Cols, List, FinalList) :-
    NextRow is Row + 1,
    Edge is Cols - 1,
    findall(N, nth0(N, H, -1), Fulcrums),
    length(Fulcrums, NFulcrums),
    (
        (NFulcrums == 1, nth0(0, Fulcrums, Index), Index > 0, Index < Edge) -> Value is Row*Cols, addRowDomain(H,Value,List,List2)
        ; List2 = List
    ),
    calcRowDomain(T, NextRow, Cols, List2, FinalList).

addRowDomain([], _, FinalList, FinalList).
addRowDomain([H|T], Value, List, FinalList) :-
    NextValue is Value + 1,
    (
        H == 0 -> append(List, [Value], List2) ; List2 = List
    ),
    addRowDomain(T, NextValue, List2, FinalList).

calcColDomain([], _, _, _, FinalList, FinalList).
calcColDomain([H|T], Col, Cols,Rows, List, FinalList) :-
    NextCol is Col + 1,
    Edge is Rows - 1,
    findall(N, nth0(N, H, -1), Fulcrums),
    length(Fulcrums, NFulcrums),
    (
        (NFulcrums == 1, nth0(0, Fulcrums, Index), Index > 0, Index < Edge) -> addColDomain(H,0,Col,Cols, List, List2)
        ; List2 = List
    ),
    calcColDomain(T, NextCol, Cols, Rows, List2, FinalList).

addColDomain([],_,_,_,FinalList,FinalList).
addColDomain([H|T], Index, Col, Cols, List, FinalList) :-
    NextI is Index + 1,
    Value is Col + (Index * Cols),
    (
        H == 0 -> append(List, [Value], List2) ; List2 = List
    ),
    addColDomain(T, NextI, Col, Cols, List2, FinalList).

applyDomain([],_).
applyDomain([H|T],DomainSet) :-
    H in_set DomainSet,
    applyDomain(T, DomainSet).

constrainPlacing([], _, _, _).
constrainPlacing([H|T], Cols, Rows, B) :-
    getNthElement(H, Cols, B, Value),
    Value #= 0,
    Line #= H/Cols,
    % Row
    getLine(0, Line, B, CurrentLine),
    findall(N, nth0(N, CurrentLine, -1), FulcrumsR),
    length(FulcrumsR, NFulcrumsRow),
    NFulcrumsRow #= 1,

    % Col
    transpose(B, B1),
    Row #= mod(H, Cols),
    getLine(0, Row, B1, CurrentRow),
    findall(NR, nth0(NR, CurrentRow, -1), FulcrumsL),
    length(FulcrumsL, NFulcrumsCol),
    NFulcrumsCol #= 1,

    % Constraints

    % Fulcrum position row
    nth0(0, FulcrumsR, FPosition1),
    length(CurrentLine, LineLength),
    FPosition1 #> 0, FPosition1 #< LineLength - 1,

    % Fulcrum position col
    nth0(0, FulcrumsL, FPosition2),
    length(CurrentRow, RowLength),
    FPosition2 #> 0, FPosition2 #< RowLength - 1,
    constrainPlacing(T, Cols, Rows, B).


getNthElement(N, Cols, Board, Value) :-
    I #= N/Cols, J #= mod(N, Cols),
    % format('[~p,~p]\n',[I,J]),
    getValueFromMatrix(Board, I, J, Value).

getLine(DesiredLine, DesiredLine, [H|_], H).
getLine(I, DesiredLine, [H | T], Line) :-
    I #< DesiredLine,
    NextI #= I + 1,
    getLine(NextI, DesiredLine, T, Line).

addSolution([], _Index, _Cols, FinalBoard, FinalBoard).
addSolution([N | T], Index, Cols, B, FinalBoard):-
    I #= N/Cols, J #= mod(N, Cols),

    replaceInMatrix(B,I,J,Index,B2),

    NextI #= Index + 1,
    addSolution(T, NextI, Cols, B2, FinalBoard).

torqueConstraint([]).
torqueConstraint([H | T]) :-
    % write(H),nl,
    findall(N, nth0(N, H, -1), Fulcrums),
    length(Fulcrums, NFulcrumsRow),
    ((NFulcrumsRow #\= 1) ; (NFulcrumsRow #= 1), nth0(N1, H, -1), checkTorque(H, N1)),
    torqueConstraint(T).


/* check if torques at both sides are equal*/
checkTorque(List, N) :-
    leftTorque(List, 0, N, 0, LeftTorque),
    rightTorque(List, N, RightTorque),
    RightTorque #= LeftTorque.
    % format('Left TORQUE: ~p   Right TORQUE: ~p\n', [LeftTorque,RightTorque]).

/* calculate torque starting from the left */
leftTorque(_ ,N, N, FinalTorque, FinalTorque).
leftTorque([H|T], I, N, Torque, FinalTorque) :-
    NextI #= I + 1,
    % format('(~p - ~p) * ~p + ~p', [N,I,H,Torque]),nl, might need this later
    TorqueTmp #= (N-I) * H + Torque,
    leftTorque(T, NextI, N, TorqueTmp, FinalTorque).

/* reverse list to calculate torque from the left (easier) */
rightTorque(List, N, FinalTorque):-
    reverse(List, ReversedList),
    length(List, L),
    NReversed #= L - N - 1,
    leftTorque(ReversedList, 0, NReversed, 0, FinalTorque).

reset_timer :- statistics(walltime,_).
print_time :-
	statistics(walltime,[_,T]),
	TS is ((T//10)*10)/1000,
	nl, write('Time: '), write(TS), write('s'), nl, nl.