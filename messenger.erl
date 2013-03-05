-module(messenger).
-export([start_server/0, server/1, logon/1, logoff/0,alluser/0, message/2, client/2]).

%%% Change the function below to return the name of the node where the
%%% messenger server runs
server_node() ->
    c1@ZJMBA.

%%% This is the server process for the "messenger"
%%% the user list has the format [{ClientPid1, Name1},{ClientPid22, Name2},...]
server(User_List) ->
	io:format("server get message",[]),
    receive
			test->
					io:format("server test 1~n",[]),
					server(User_List);
        {From, logon, Name} ->
            New_User_List = server_logon(From, Name, User_List),
            server(New_User_List);
        {From, logoff} ->
            New_User_List = server_logoff(From, User_List),
            server(New_User_List);
        {From, message_to, To, Message} ->
            server_transfer(From, To, Message, User_List),
            io:format("list is now: ~p~n", [User_List]),
            server(User_List);
		{From,print_all_user}->
				print_all_user(User_List),
				server(User_List)
    end.

print_all_user([{From,Name}|User_List])->
		io:format("~w~n",[Name]),
		print_all_user(User_List);

print_all_user([])->
		all_print.


%%% Start the server
start_server() ->
	case whereis(messenger) of
			undefined ->
    				register(messenger, spawn(messenger, server, [[]]));
			_->
					unregister(messenger),
					register(messenger, spawn(messenger, server, [[]]))
	end.




%%% Server adds a new user to the user list
server_logon(From, Name, User_List) ->
    %% check if logged on anywhere else
	io:format("server_logon 1 ~w ~w ~w ~n",[From,Name,User_List]),
    case lists:keymember(Name, 2, User_List) of
        true ->
            From ! {messenger, stop, user_exists_at_other_node},  %reject logon
            User_List;
        false ->
            From ! {messenger, logged_on},
			io:format("~w logon",[Name]),
            [{From, Name} | User_List]        %add user to the list
    end.

%%% Server deletes a user from the user list
server_logoff(From, User_List) ->
    lists:keydelete(From, 1, User_List).


%%% Server transfers a message between user
server_transfer(From, To, Message, User_List) ->
    %% check that the user is logged on and who he is
    case lists:keysearch(From, 1, User_List) of
        false ->
            From ! {messenger, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            server_transfer(From, Name, To, Message, User_List)
    end.
%%% If the user exists, send the message
server_transfer(From, Name, To, Message, User_List) ->
    %% Find the receiver and send the message
    case lists:keysearch(To, 2, User_List) of
        false ->
            From ! {messenger, receiver_not_found};
        {value, {ToPid, To}} ->
            ToPid ! {message_from, Name, Message}, 
            From ! {messenger, sent} 
    end.


%%% User Commands
logon(Name) ->
    case whereis(mess_client) of 
        undefined ->
				io:format("clinet logon ~w~n",[Name]),
            register(mess_client, spawn(messenger, client, [server_node(), Name]));
        _ -> already_logged_on
    end.

logoff() ->
    mess_client ! logoff.

message(ToName, Message) ->
    case whereis(mess_client) of % Test if the client is running
        undefined ->
            not_logged_on;
        _ -> mess_client ! {message_to, ToName, Message},
             ok
end.

alluser() ->
		mess_client ! alluser.
%%% The client process which runs on each server node
client(Server_Node, Name) ->
		io:format("clinet 1 ~w ~w ~n",[Server_Node,Name]),
    {messenger, Server_Node} ! {self(), logon, Name},
		io:format("clinet 2 ~w ~w ~n",[Server_Node,Name]),
    await_result(),
	io:format("clinet 3  ~w ~w ~n",[Server_Node,Name]),
    client(Server_Node),
		io:format("clinet 4  ~w ~w ~n",[Server_Node,Name]).


client(Server_Node) ->
    receive
		test->
				io:format("clinet test",[]);
		alluser ->
				{messenger,Server_Node} ! {self(),print_all_user};
        logoff ->
            {messenger, Server_Node} ! {self(), logoff},
            exit(normal);
        {message_to, ToName, Message} ->
            {messenger, Server_Node} ! {self(), message_to, ToName, Message},
            await_result();
        {message_from, FromName, Message} ->
            io:format("Message from ~p: ~p~n", [FromName, Message])
    end,
    client(Server_Node).

%%% wait for a response from the server
await_result() ->
	io:format("await 1~n",[]),
    receive
        {messenger, stop, Why} -> % Stop the client 
            io:format("~p~n", [Why]),
            exit(normal);
        {messenger, What} ->  % Normal response
            io:format("~p~n", [What])
    end,
	io:format("await end 1~n",[]).

