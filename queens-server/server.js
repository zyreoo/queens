const express = require("express");
const http = require("http");
const cors = require("cors");
const {v4: uuidv4} = require('uuid');

const app = express();
app.use(cors());
app.use(express.json());

const suits = ["Clubs", "Spades", "Diamonds", "Hearts"];
const ranks = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"];
const values = Object.fromEntries(ranks.map((r) => [r, parseInt(r)]));

const MAX_PLAYERS = 2;
let players = [];
let deck = [];

let centerCard = null;
let currentTurnIndex = 0;


function shuffleDeck(deck){
  for (let i = deck.length -1; i > 0; i--){
    const j = Math.floor(Math.random() * (i+1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
}


function createDeck() {
  deck = [];
  for (let suit of suits){
    for (let rank of ranks){
      deck.push({ suit, rank, value: values[rank] });
    }
  }
  shuffleDeck(deck);
}

function resetGame() {
  players = [];
  createDeck();
  centerCard = null;
  currentTurnIndex = 0;
  console.log("game state reset.");
}

function drawHand(){
  return deck.splice(0, 4); 
}


function getCenterCard() {
  console.log(" getCenterCard called. Deck length:", deck.length, "Center card is currently:", centerCard);


  if (!centerCard) {
    if (deck.length === 0) {
      createDeck();
      console.log("Deck recreated to get center card.");
    }
    centerCard = deck.pop();
    console.log("Center card set to:", centerCard);
  }
  return centerCard;
}


function nextTurn() {
  const previousTurn = currentTurnIndex;
  currentTurnIndex = (currentTurnIndex + 1) % players.length;
  console.log(`turn changed: ${previousTurn} to ${currentTurnIndex}`);
}



createDeck()

app.post("/join", (req, res) => {
  try {
    
    const incomingId = req.body.player_id;

    if (incomingId) {
      const existing = players.find(p => p.id === incomingId);
      if (existing) {
        return res.json({
          status: "ok",
          player_id: existing.id,
          player_index: existing.index,
          hand: existing.hand,
          center_card: getCenterCard(),
          current_turn_index: currentTurnIndex,
          total_players: players.length
        });
      }
    }

    if (players.length === 0) {
      createDeck();
      centerCard = null;
      console.log(" first player joined: resetting deck and center card.");
    }
    
    if (players.length >= MAX_PLAYERS) {
      return res.status(400).json({
        status: 'error',
        message: 'Game is full'
      });
    }

    const playerID = uuidv4(); 
    const newPlayer = {
      id: playerID,
      hand: drawHand(), 
      index: players.length,
      lastSeen: Date.now()
    };

    players.push(newPlayer);
    console.log(`player ${newPlayer.index} joined the game,  total players: ${players.length}`);


    const currentCenter = getCenterCard();

    console.log(" center card: ", currentCenter)


    res.json({
      status: 'ok', 
      player_id: playerID,
      player_index: newPlayer.index, 
      hand: newPlayer.hand, 
      center_card: currentCenter, 
      current_turn_index: currentTurnIndex,
      total_players: players.length
    });



  } catch (error) {
    console.error('Error in join:', error);
    res.status(500).json({
      status: 'error',
    });
  }
});

app.post("/play_card", (req, res) => {
  try {
    const { player_index, card } = req.body;

    if (player_index !== currentTurnIndex) {
      return res.status(403).json({ 
        status: "error", 
        message: `not ur turn current turn: ${currentTurnIndex} ur index: ${player_index}`,
        game_state: {
          current_turn: currentTurnIndex,
          total_players: players.length,
        }
      });
    }

    const player = players.find(p => p.index === player_index);

    if (!player) {
      return res.status(404).json({
        status: "error",
        message: "Player not found"
      });
    }

    centerCard = card;
    nextTurn();
    console.log(`Player ${player_index} played card. Next turn: ${currentTurnIndex}`);

    res.json({
      status: "ok",
      center_card: centerCard,
      current_turn_index: currentTurnIndex,
      total_players: players.length,
      active_players: players.map(p => p.index)
    });
  } catch (error) {
    console.error('Error in play_card:', error);
    res.status(500).json({
      status: 'error',
    });
  }
});

app.get("/state", (req, res) => {
  try {
    res.json({
      center_card: centerCard,
      current_turn_index: currentTurnIndex,
      deck_count: deck.length,
      total_players: players.length,
      players: players.map(p => ({ 
        index: p.index, 
        hand_size: p.hand.length
      }))
    });
  } catch (error) {
    console.error('Error in state:', error);
    res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});


app.post("/reset", (req, res) => {
  resetGame();
  res.json({
    status: 'ok',
    message: 'Game reset complete'
  });
});

http.createServer(app).listen(3000, () => {
  console.log("Serverr  unning on http://localhost:3000");
}); 