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
let reactionMode = false;
let reactionValue = null;
let reactingPlayers = [];
let queensTriggered = false;
let queensPlayerIndex = null;
let finalRoundActive = false;
let finalTurnCount = 0;

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
      deck.push({ suit, rank, value: values[rank], card_id: `${suit}_${rank}_${Date.now()}`});
    }
  }
  shuffleDeck(deck);
}

function resetGame() {
  players = [];
  createDeck();
  centerCard = null;
  currentTurnIndex = 0;
  reactionMode = false;
  reactionValue = null;
  reactingPlayers = [];
  queensTriggered = false;
  queensPlayerIndex = null;
  finalRoundActive = false;
  finalTurnCount = 0;
  console.log("game state reset.");
}

function drawHand(){
  return deck.splice(0, 4).map(card => ({ ...card, card_id: `${card.suit}_${card.rank}_${Date.now()}` }));
}


function getCenterCard() {
  if (!centerCard && deck.length > 0) {
    centerCard = deck.pop();
    console.log("Center card set to:", centerCard);
  }
  return centerCard;
}


function nextTurn() {
  if (finalRoundActive) {
    finalTurnCount++;
    if (finalTurnCount >= players.length) {
      const result = calculateFinalScore();
      return { game_over: true, ...result };
    }
  }
  currentTurnIndex = (currentTurnIndex + 1) % players.length;
  console.log(`Turn changed to player ${currentTurnIndex}`);
  return { game_over: false };
}

function calculateFinalScore() {
  let scores = [];
  let totalOtherScores = 0;

  let lowestScore = Infinity;

  let queensScore = 0;
  players.forEach((player, i) => {
    let handScore = 0;
    player.hand.forEach(card => {
      if (card.rank === "12") handScore += 0;
      else if (card.rank === "1") handScore += 1;
      else if (["11", "13"].includes(card.rank)) handScore += 10;
      else handScore += parseInt(card.rank);
    });
    scores.push(handScore);
    if (i === queensPlayerIndex) queensScore = handScore;
    else totalOtherScores += handScore;
    if (handScore < lowestScore) lowestScore = handScore;
  });

  if (queensScore === lowestScore) {
    return { winner: queensPlayerIndex, message: `player ${queensPlayerIndex + 1} wins!` };
  } else {
    players[queensPlayerIndex].score = totalOtherScores;
    players.forEach((p, i) => { if (i !== queensPlayerIndex) p.score = 0; });
    return { winner: null, message: `player ${queensPlayerIndex + 1} called queens but didn't have the lowest score. They get ${totalOtherScores} points.` };
  }
}

createDeck();

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
      lastSeen: Date.now(),
      score: 0 
    };

    players.push(newPlayer);
    console.log(`player ${newPlayer.index} joined the game,  total players: ${players.length}`);

    res.json({
      status: 'ok',
      player_id: playerID,
      player_index: newPlayer.index,
      hand: newPlayer.hand,
      center_card: getCenterCard(),
      current_turn_index: currentTurnIndex,
      total_players: players.length
    });

  } catch (error) {
    console.error('Error in join:', error);
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
});

app.post("/play_card", (req, res) => {
  try {
    const { player_index, card } = req.body;

    if (player_index !== currentTurnIndex && !reactionMode) {
      return res.status(403).json({
        status: "error",
        message: `not ur turn. Current turn: ${currentTurnIndex}, ur index: ${player_index}`
      });
    }

    const player = players.find(p => p.index === player_index);

    if (!player) {
      return res.status(404).json({
        status: "error",
        message: "Player not found"
      });
    }
    const cardIndex = player.hand.findIndex(c => c.card_id === card.card_id);
    if (cardIndex === -1) {
      return res.status(400).json({ status: "error", message: "Card not in hand" });
    }

    if (reactionMode && card.value !== reactionValue) {
      if (!reactingPlayers.includes(player_index)) {
        reactingPlayers.push(player_index);
        player.hand.push(deck.pop());
        return res.json({
          status: "ok",
          hand: player.hand,
          message: "Invalid card, penalty card added",
          center_card: centerCard,
          current_turn_index: currentTurnIndex,
          total_players: players.length
        });
      }
    }

    player.hand.splice(cardIndex, 1); 
    centerCard = card;
    let response = { 
      status: "ok", 
      center_card: centerCard, 
      current_turn_index: currentTurnIndex, 
      total_players: players.length, 
      hand: player.hand
  };
  
  if (card.rank === "13") { 
      player.hand.forEach(c => c.permanent_face_up = true); 
      response.message = "King played! Your cards are revealed.";
      const turnResult = nextTurn();
      response.current_turn_index = currentTurnIndex;
      if (turnResult.game_over) {
          response = { ...response, ...turnResult };
      }
  } else if (card.rank === "11") {
      response.jack_swap_mode = true;
      response.message = "Jack played! Select a card to swap.";
  } else if (card.rank === "12") { 
      const nextPlayerIndex = (player_index + 1) % players.length;
      players[nextPlayerIndex].hand.push(card);
      centerCard = null;
      response.center_card = centerCard;
      const turnResult = nextTurn();
      response.current_turn_index = currentTurnIndex; 
      if (turnResult.game_over) {
          response = { ...response, ...turnResult };
      }
  } else {
      reactionMode = true;
      reactionValue = card.value;
      reactingPlayers = [];
      response.message = `match! Play a ${card.value} within 3 seconds.`;
      response.reaction_mode = reactionMode;
      response.reaction_value = reactionValue;
      setTimeout(() => {
          reactionMode = false;
          reactionValue = null;
          const turnResult = nextTurn();
          console.log("Reaction mode ended, turn advanced to:", currentTurnIndex);
      }, 3000);
  }
  
  if (!["11", "12", "13"].includes(card.rank) && card.rank !== "13") {
      const turnResult = nextTurn();
      response.current_turn_index = currentTurnIndex; 
      if (turnResult.game_over) {
          response = { ...response, ...turnResult };
      }
  }
  
  console.log("Card played, new center card:", centerCard, "new turn index:", currentTurnIndex);


    res.json(response);


  } catch (error) {
    console.error('Error in play_card:', error);
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
});


app.post("/jack_swap", (req, res) => {
  try {
    const { player_index, from_card_id, to_card_id } = req.body;
    if (player_index !== currentTurnIndex) {
      return res.status(403).json({ status: "error", message: "Not your turn" });
    }

    const player = players[player_index];
    const opponent = players.find(p => p.index !== player_index);
    const fromCardIndex = player.hand.findIndex(c => c.card_id === from_card_id);
    const toCardIndex = opponent.hand.findIndex(c => c.card_id === to_card_id);

    if (fromCardIndex === -1 || toCardIndex === -1) {
      return res.status(400).json({ status: "error", message: "Invalid card selection" });
    }

    const temp = player.hand[fromCardIndex];
    player.hand[fromCardIndex] = opponent.hand[toCardIndex];
    opponent.hand[toCardIndex] = temp;

    nextTurn();
    res.json({
      status: "ok",
      center_card,
      current_turn_index: currentTurnIndex,
      player_hand: player.hand,
      opponent_hand_size: opponent.hand.length
    });
  } catch (error) {
    console.error("Error in jack_swap:", error);
    res.status(500).json({ status: "error", message: "Internal server error" });
  }
});

app.post("/call_queens", (req, res) => {
  try {
    const { player_index } = req.body;
    if (player_index !== currentTurnIndex) {
      return res.status(403).json({ status: "error", message: "Not your turn" });
    }

    queensTriggered = true;
    queensPlayerIndex = player_index;
    finalRoundActive = true;
    finalTurnCount = 0;
    nextTurn();

    res.json({
      status: "ok",
      message: "Queens called! Final round started.",
      current_turn_index: currentTurnIndex
    });
  } catch (error) {
    console.error("Error in call_queens:", error);
    res.status(500).json({ status: "error", message: "Internal server error" });
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
        hand_size: p.hand.length,
        hand: p.hand
      })),
      reaction_mode: reactionMode,
      reaction_value: reactionValue,
      queens_triggered: queensTriggered,
      final_round_active: finalRoundActive
    });
    console.log("State sent to client - center card:", centerCard, "turn index:", currentTurnIndex)
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
  console.log("Server  running on http://localhost:3000");
}); 