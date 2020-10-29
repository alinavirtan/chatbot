:- ensure_loaded('chat.pl').

% Returneaza true dacă regula dată ca argument se potriveste cu
% replica data de utilizator. Replica utilizatorului este
% reprezentata ca o lista de tokens. Are nevoie de
% memoria replicilor utilizatorului pentru a deduce emoția/tag-ul
% conversației.
% match_rule/3
same(L1, L2) :- L1 = L2.

match_rule(Tokens, UserMemory, rule(Expression, _, _, _, _)) :- get_emotion(UserMemory, Emotion), 
																 Emotion == neutru,
																 same(Tokens, Expression).
match_rule(Tokens, UserMemory, rule(Expression, _, _, [Emo], _)) :- get_emotion(UserMemory, Emotion), 
																 Emotion == Emo,
																 same(Tokens, Expression).																 

% Primeste replica utilizatorului (ca lista de tokens) si o lista de
% reguli, iar folosind match_rule le filtrează doar pe cele care se
% potrivesc cu replica dată de utilizator.
% find_matching_rules/4
% find_matching_rules(+Tokens, +Rules, +UserMemory, -MatchingRules)
find_matching_rules(Tokens, Rules, UserMemory, MatchingRules) :- findall(Res,  (member(Res, Rules), match_rule(Tokens, UserMemory, Res)), MatchingRules).

% Intoarce in Answer replica lui Gigel. Selecteaza un set de reguli
% (folosind predicatul rules) pentru care cuvintele cheie se afla in
% replica utilizatorului, in ordine; pe setul de reguli foloseste
% find_matching_rules pentru a obtine un set de raspunsuri posibile.
% Dintre acestea selecteaza pe cea mai putin folosita in conversatie.
%
% Replica utilizatorului este primita in Tokens ca lista de tokens.
% Replica lui Gigel va fi intoarsa tot ca lista de tokens.
%
% UserMemory este memoria cu replicile utilizatorului, folosita pentru
% detectarea emotiei / tag-ului.
% BotMemory este memoria cu replicile lui Gigel și va si folosită pentru
% numararea numarului de utilizari ale unei replici.
%
% In Actions se vor intoarce actiunile de realizat de catre Gigel in
% urma replicii (e.g. exit).
%
% Hint: min_score, ord_subset, find_matching_rules


select_rules(Tokens, MatchyRules) :- findall(R, (rules(CuvinteCheie, Rules), ord_subset(CuvinteCheie, Tokens), member(R, Rules)), MatchyRules).

select_all_answers([], []).
select_all_answers([rule(_, [], _, _, _)|RestRules], Ans) :- select_all_answers(RestRules, Ans).
select_all_answers([rule(_, [Reply|Replies], _, _, _) | RestRules], [Reply|Ans]) :- select_all_answers([rule(_, Replies, _, _, _)|RestRules], Ans). 
 
all_key_value_tuples(BotMemory, PossibleAnswers, KeyValueList) :- findall((Key, Value), (member(Answer, PossibleAnswers),
																						unwords(Answer, Key), 
																						get_value(BotMemory, Key, Value)), KeyValueList).

select_actions(Tokens, Actions) :- member(Tokens, [[pa], [bye], [la, revedere]]), Actions = [exit].
select_actions(Tokens, Actions) :- \+ member(Tokens, [[pa], [bye], [la, revedere]]), Actions = [].

select_valid_answers([[nu, inteleg]], [[nu, inteleg]]).
select_valid_answers(AllAnswers, PossibleAnswers) :- findall(Elem, (member(Elem,  AllAnswers), Elem \= [nu, inteleg]), PossibleAnswers).

% [[salutare], [salut], [nu, inteleg]]
% select_answer/5
% select_answer(+Tokens, +UserMemory, +BotMemory, -Answer, -Actions)
select_answer(Tokens, UserMemory, BotMemory, Answer, Actions) :- 
					select_rules(Tokens, MatchyRules), 
					find_matching_rules(Tokens, MatchyRules, UserMemory, PossibleRules),
					select_all_answers(PossibleRules, AllAnswers),
					select_valid_answers(AllAnswers, PossibleAnswers),			 
					all_key_value_tuples(BotMemory, PossibleAnswers, KeyValueList),
					min_element(KeyValueList, Min), words(Min, Answer),
					select_actions(Tokens, Actions).
	
% Esuează doar daca valoarea exit se afla in lista Actions.
% Altfel, returnează true.
% handle_actions/1
% handle_actions(+Actions)
handle_actions(Actions) :- \+ member(exit, Actions).


% Caută frecvența (numărul de apariți) al fiecarui cuvânt din fiecare
% cheie a memoriei.
% e.g
% ?- find_occurrences(memory{'joc tenis': 3, 'ma uit la box': 2, 'ma uit la un film': 4}, Result).
% Result = count{box:2, film:4, joc:3, la:6, ma:6, tenis:3, uit:6, un:4}.
% Observați ca de exemplu cuvântul tenis are 3 apariți deoarce replica
% din care face parte a fost spusă de 3 ori (are valoarea 3 în memorie).
% Recomandăm pentru usurința să folosiți înca un dicționar în care să tineți
% frecvențele cuvintelor, dar puteți modifica oricum structura, această funcție
% nu este testată direct.

% pune cuvintele din fiecare intrare in dictionar

% adaug la dictionarul de cuvinte cuvintele din cheia-propozitie curenta a dictionarului UserMemory																	 
put_entry([], _, Dict, Dict).
put_entry([T | Tokens], Freq, Dict, NewDict) :- put_entry(Tokens, Freq, Dict, DictPrev),
												get_value(DictPrev, T, Val), NewVal is Val + Freq, 
												NewDict = DictPrev.put(T, NewVal).

% creeaza dictionarul cu toate cuvintele aflte in cheile-propozitii ale dictionarului UserMemory
create_dictionary(_, [], count{}).
create_dictionary(UserMemory, [Key | UserKeys], NewDict) :-  create_dictionary(UserMemory, UserKeys, Dict),
															 words(Key, Tokens), get_value(UserMemory, Key, Freq), 
															 put_entry(Tokens, Freq, Dict, NewDict).

% find_occurrences/2
% find_occurrences(+UserMemory, -Result)
find_occurrences(UserMemory, Result) :- dict_keys(UserMemory, UserKeys), create_dictionary(UserMemory, UserKeys, Result).

% Atribuie un scor pentru fericire (de cate ori au fost folosit cuvinte din predicatul happy(X))
% cu cât scorul e mai mare cu atât e mai probabil ca utilizatorul să fie fericit.
% get_happy_score/2
% get_happy_score(+UserMemory, -Score)

happy_helper([], _, 0).
happy_helper([Key | Keys], Dict, NewScore) :- happy_helper(Keys, Dict, Score), happy(Key), get_value(Dict, Key, Value), NewScore is Score + Value.
happy_helper([Key | Keys], Dict, NewScore) :- happy_helper(Keys, Dict, Score), \+ happy(Key), NewScore is Score. 

get_happy_score(UserMemory, Score) :- find_occurrences(UserMemory, Dict), dict_keys(Dict, Keys), happy_helper(Keys, Dict, Score).

% Atribuie un scor pentru tristețe (de cate ori au fost folosit cuvinte din predicatul sad(X))
% cu cât scorul e mai mare cu atât e mai probabil ca utilizatorul să fie trist.
% get_sad_score/2
% get_sad_score(+UserMemory, -Score)

sad_helper([], _, 0).
sad_helper([Key | Keys], Dict, NewScore) :- sad_helper(Keys, Dict, Score), sad(Key), get_value(Dict, Key, Value), NewScore is Score + Value.
sad_helper([Key | Keys], Dict, NewScore) :- sad_helper(Keys, Dict, Score), \+ sad(Key), NewScore is Score.

get_sad_score(UserMemory, Score) :- find_occurrences(UserMemory, Dict), dict_keys(Dict, Keys), sad_helper(Keys, Dict, Score). 

% Pe baza celor doua scoruri alege emoția utilizatorul: `fericit`/`trist`,
% sau `neutru` daca scorurile sunt egale.
% e.g:
% ?- get_emotion(memory{'sunt trist': 1}, Emotion).
% Emotion = trist.
% get_emotion/2
% get_emotion(+UserMemory, -Emotion)
get_emotion(UserMemory, Emotion) :- get_sad_score(UserMemory, SadScore), get_happy_score(UserMemory, HappyScore), SadScore > HappyScore, Emotion = trist.
get_emotion(UserMemory, Emotion) :- get_sad_score(UserMemory, SadScore), get_happy_score(UserMemory, HappyScore), SadScore < HappyScore, Emotion = fericit.
get_emotion(UserMemory, Emotion) :- get_sad_score(UserMemory, SadScore), get_happy_score(UserMemory, HappyScore), SadScore == HappyScore, Emotion = neutru.

% Atribuie un scor pentru un Tag (de cate ori au fost folosit cuvinte din lista tag(Tag, Lista))
% cu cât scorul e mai mare cu atât e mai probabil ca utilizatorul să vorbească despre acel subiect.
% get_tag_score/3
% get_tag_score(+Tag, +UserMemory, -Score)
get_tag_score(_Tag, _UserMemory, _Score) :- fail.

% Pentru fiecare tag calculeaza scorul și îl alege pe cel cu scorul maxim.
% Dacă toate scorurile sunt 0 tag-ul va fi none.
% e.g:
% ?- get_tag(memory{'joc fotbal': 2, 'joc box': 3}, Tag).
% Tag = sport.
% get_tag/2
% get_tag(+UserMemory, -Tag)
get_tag(_UserMemory, _Tag) :- fail.