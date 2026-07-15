# Erlang Server

Main modules:

- `server.erl` - startup, managers, TCP socket and accept loop.
- `connection_session.erl` - one process per client; parsing, state-based validation, routing and serialization.
- `auth_manager.erl` - registration, login, logout and account cancellation.
- `queue_manager.erl` - waiting queue and matchmaking for 3 or 4 players.
- `game_supervisor.erl` - limit of 4 simultaneous matches and match lifecycle management.
- `game_session.erl` - bridge between the supervisor, sessions and the game engine.
- `game_engine.erl` - physics, movement, objects, collisions, captures and ticks.
- `scoreboard_manager.erl` - in-memory scoreboard.

Compile in the Erlang shell:

```erlang
c(auth_manager).
c(scoreboard_manager).
c(game_engine).
c(game_session).
c(game_supervisor).
c(queue_manager).
c(connection_session).
c(server).
```

Start:

```erlang
server:start().
```
