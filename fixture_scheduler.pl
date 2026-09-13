:- use_module(library(clpfd)).

% --- Groups --- 
% white space after the team names is weird as it helps with the pretty print later
group(group1, ['team1  ', 'team2  ', 'team3  ', 'team4  ', 'team5  ']).
group(group2, ['team6  ', 'team7  ', 'team8  ', 'team9  ', 'team10 ']).
group(group3, ['team11 ', 'team12 ', 'team13 ', 'team14 ', 'team15 ']).
group(group4, ['team16 ', 'team17 ', 'team18 ', 'team19 ', 'team20 ']).
group(group5, ['team21 ', 'team22 ', 'team23 ', 'team24 ', 'team25 ']).
group(group6, ['team26 ', 'team27 ', 'team28 ', 'team29 ', 'team30 ']).

% gets every team in every group
all_teams(Teams) :-
  findall(T, (group(_, Ts),  member(T, Ts)), Teams).

% generates every possible unique match within each group 
all_matches(Matches) :-
  findall(match_base(A, B),  % match_base(A, B) represnets 
    (group(_, Teams), append(_, [A|Rest], Teams), member(B, Rest)),
    Matches).

% Main predicate: produces valid schedule 
schedule(S) :-
  all_matches(BaseMatches),

  between(25, 50, MaxDay), % try diffent schedule lengths

  % attach clpfd cariables (Day = match day, Dir = home/away indicator)
  attach_vars(BaseMatches, FullMatches, Days, Dirs),

  % Domain Constraints
  Days ins 1..MaxDay, % Days are between 1 and MaxDay
  Dirs ins 0..1, % 0 = A's home or 1 = B's home

  % Global Constraints
  limit_matches_per_day(Days, MaxDay),

  all_teams(Teams),
  maplist(team_constraints(FullMatches), Teams),

  % Reduces symmetric solutions
  break_symmetries(FullMatches),

  % labels the variables for each valid solution
  append(Days, Dirs, AllVars),
  labeling([ff], AllVars),
  
  % sorts the matches by day
  sort(4, @=<, FullMatches, SortedFullMatches),

  format_to_list(SortedFullMatches, S),

  % pretty printing the output so it doesn't end up as a big list thats difficult to read
  format('~n~w~t~10|~w~t~31|~w~n', ['DAY', 'TEAMS', 'GROUP']),
  format('-------------------------------------~n', []),

  print_rows(S).

format_to_list([], []).
format_to_list([match(A, B, Dir, Day)|Ms], [Fixture|Rest]) :-
  ( Dir #= 0 -> Fixture = (A, B, Day) ; Fixture = (B, A, Day) ),
  format_to_list(Ms, Rest).

print_rows([]).
print_rows([(Home, Away, Day)|Rest]) :-
  group(G, Teams), member(Home, Teams), !,
  format('Day ~w:~t~10|~w vs  ~w~t~31|~w~n', [Day, Home, Away, G]),
  print_rows(Rest).

break_symmetries(Matches) :-
  forall(
    group(_, [FirstTeam|_]),
    (
      findall(Day, member(match(FirstTeam, _, _, Day), Matches), FirstTeamDays),
      chain(FirstTeamDays, #<)
    )
  ).

% converts base matches into full matches with variables
% match(A, B, Dir, Day)
attach_vars([], [], [], []).
attach_vars([match_base(A, B)|Ms], [match(A, B, Dir, Day)|Fs], [Day|Days], [Dir|Dirs]) :-
  attach_vars(Ms, Fs, Days, Dirs).

% makes sure that no more than 3 matches happen in a per day

limit_matches_per_day(Days, MaxDay) :-
  numlist(1, MaxDay, PossibleDays),
  length(Counts, MaxDay),
  Counts ins 0..3,
  pairs_keys_values(Pairs, PossibleDays, Counts),
  global_cardinality(Days, Pairs). % uses global_cardinality to count number of matches per day

% here is where all the constraints that are applied to the teams are these include: matches have to be at least 5 days apart and they have to have exactly 2 home games and 2 away games
team_constraints(Matches, Team) :-
  team_matches(Team, Matches, TeamDays, HomeIndicators),

  pairwise_diff(TeamDays, 5), % enforces that teams have at least 5 days rest

  sum(HomeIndicators, #=, 2). % enfores that they have exactly 2 home games (if they have 2 home games then they have 2 away games so another check isn't needed for the number of away matches)

% collects all the match days and home/away indicators for a given team
team_matches(_, [], [], []).
team_matches(T, [match(A, B, Dir, Day)|Ms], Days, HomeInds) :-
  (T == A ->
    Days = [Day|RestDays],
    H #= 1 - Dir,
    HomeInds = [H|RestInds],
    team_matches(T, Ms, RestDays, RestInds)
  ; T == B ->
    Days = [Day|RestDays],
    H #= Dir,
    HomeInds = [H|RestInds],
    team_matches(T, Ms, RestDays, RestInds)
  ;
    team_matches(T, Ms, Days, HomeInds)
  ).

% ensures all matches for all teams are at least a set distance (Gap) apart
pairwise_diff([], _).
pairwise_diff([D|Ds], Gap) :-
  maplist(diff_from(D, Gap), Ds),
  pairwise_diff(Ds, Gap).

% absolute difference between days must be greater than or equal to Gap
diff_from(D1, Gap, D2) :-
  abs(D1 - D2) #>= Gap.

