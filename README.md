# Multiplayer Concurrent Game

Distributed client-server multiplayer game developed as an academic project for the Concurrent Programming course at the University of Minho.

## Overview

The project implements a real-time multiplayer game in which players move through a two-dimensional environment, interact with objects and compete to achieve the highest score.

The system follows a distributed client-server architecture:

- the graphical client was developed in Java with Processing;
- the backend server was developed in Erlang;
- communication between clients and server is performed through TCP sockets.

## Main Features

- User registration, authentication and account management
- Matchmaking queue
- Concurrent management of multiple game sessions
- Real-time server-side game simulation
- Player movement and collision handling
- Captures, mass variation and object generation
- Score calculation and scoreboard management
- Support for three to four players per match
- Support for up to four simultaneous matches

## Technologies

- Erlang
- Java
- Processing
- TCP sockets

## Architecture

The project is divided into three main components:

```text
src/
├── servidor_erlang/      # Concurrent backend server
├── cliente_java/         # Networking, input and game-state logic
└── cliente_processing/   # Graphical user interface
```

The Erlang backend is composed of independent modules responsible for authentication, client connections, matchmaking, game supervision, game simulation and score management.

## My Contribution

I was responsible for the development of the backend in Erlang.

This included work on the server-side architecture and the integration of authentication, connections, matchmaking, game sessions, game logic and scoreboard management.

## Running the Project

### 1. Compile and start the Erlang server

From the server directory:

```bash
cd src/servidor_erlang
make compile
erl
```

Inside the Erlang shell:

```erlang
server:start().
```

The server listens on:

```text
localhost:12345
```

### 2. Compile the Java client library

From the Java client directory:

```bash
cd src/cliente_java
make compile
```

This generates `client.jar` and copies it to the Processing project.

### 3. Run the graphical client

1. Open the Processing IDE.
2. Open `src/cliente_processing/MiniJogo/MiniJogo.pde`.
3. Run the sketch.
4. Open three or four clients to create a match.

## Project Structure

```text
├── docs/
│   ├── protocolo_tcp/
│   │   └── protocolo.txt
│   ├── .DS_Store
│   └── relatorio.pdf
├── src/
│   ├── cliente_java/
│   │   ├── out/
│   │   │   ├── input/
│   │   │   │   └── InputHandler.class
│   │   │   ├── main/
│   │   │   │   └── GameClient.class
│   │   │   ├── mock/
│   │   │   │   └── MockServer.class
│   │   │   ├── network/
│   │   │   │   ├── MessageProtocol$Message.class
│   │   │   │   ├── MessageProtocol$MessageType.class
│   │   │   │   ├── MessageProtocol.class
│   │   │   │   ├── ServerConnection$1.class
│   │   │   │   └── ServerConnection.class
│   │   │   └── state/
│   │   │       ├── GamePhase.class
│   │   │       ├── GameState.class
│   │   │       ├── ObjectData$Type.class
│   │   │       ├── ObjectData.class
│   │   │       └── PlayerData.class
│   │   ├── src/
│   │   │   ├── input/
│   │   │   │   └── InputHandler.java
│   │   │   ├── main/
│   │   │   │   └── GameClient.java
│   │   │   ├── mock/
│   │   │   │   └── MockServer.java
│   │   │   ├── network/
│   │   │   │   ├── MessageProtocol.java
│   │   │   │   └── ServerConnection.java
│   │   │   └── state/
│   │   │       ├── GamePhase.java
│   │   │       ├── GameState.java
│   │   │       ├── ObjectData.java
│   │   │       └── PlayerData.java
│   │   ├── Makefile
│   │   ├── README.md
│   │   └── client.jar
│   ├── cliente_processing/
│   │   └── MiniJogo/
│   │       ├── code/
│   │       │   └── client.jar
│   │       ├── MiniJogo.pde
│   │       ├── README.txt
│   │       ├── ScreenGame.pde
│   │       ├── ScreenGameOver.pde
│   │       ├── ScreenLogin.pde
│   │       ├── ScreenWaiting.pde
│   │       ├── UIHelper.pde
│   │       └── sketch.properties
│   ├── servidor_erlang/
│   │   ├── Makefile
│   │   ├── README.md
│   │   ├── auth_manager.beam
│   │   ├── auth_manager.erl
│   │   ├── connection_session.beam
│   │   ├── connection_session.erl
│   │   ├── game_engine.beam
│   │   ├── game_engine.erl
│   │   ├── game_models.hrl
│   │   ├── game_session.beam
│   │   ├── game_session.erl
│   │   ├── game_supervisor.beam
│   │   ├── game_supervisor.erl
│   │   ├── queue_manager.beam
│   │   ├── queue_manager.erl
│   │   ├── scoreboard_manager.beam
│   │   ├── scoreboard_manager.erl
│   │   ├── server.beam
│   │   └── server.erl
│   └── .DS_Store
├── README.md
└── Relatorio_Grupo17PC.pdf
```

The TCP communication protocol is documented in [protocol](docs/protocolo_tcp/protocolo.txt).

## Academic Context

- Course: Concurrent Programming
- Degree: Computer Science
- University: University of Minho
- Academic year: 2025/2026
- Project grade: 19/20
- Group project
