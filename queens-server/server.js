const express = require('express');
const http = require('http');
const fs = require('fs');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const suits = ["Clubs", "Spades", "Diamonds", "Hearts"];
const ranks = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"];
const values = Object.fromEntries(ranks.map(r => [r, parseInt(r)]));

let players = [];
let deck = [];
let centerCard = null;
let currentPlayerIndex = 0;

function createDeck() {
  deck = [];
  for (let suit of suits) {
    for (let rank of ranks) {
      deck.push({ suit, rank, value: values[rank] });
    }
  }
  deck.sort(() => Math.random() - 0.5);
}

function drawHand() {
  return deck.splice(0, 4);
}

function getCenterCard() {
  if (!centerCard) centerCard = deck.pop();
  return centerCard;
}

function nextTurn() {
  currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
}

app.post('/join', (req, res) => {
  if (deck.length === 0) createDeck();

  const newPlayer = {
    id: Date.now(),
    hand: drawHand(),
  };
  players.push(newPlayer);
  console.log(' Join request received:', req.body);
  res.json({
    status: 'ok',
    message: `Joined room ${req.body.room_id}`,
    player_id: newPlayer.id,
    hand: newPlayer.hand,
    center_card: getCenterCard()
  });
});

app.post('/play_card', (req, res) => {
  const { player_id, card } = req.body;
  centerCard = card;
  console.log(`Player ${player_id} played`, card);
  nextTurn();
  res.json({ status: 'ok', center_card: centerCard, next_player_id: players[currentPlayerIndex].id });
});

app.get('/state', (req, res) => {
  res.json({
    center_card: centerCard,
    current_player_id: players[currentPlayerIndex]?.id || null,
    deck_count: deck.length
  });
});

const sslOptions = {
  key: fs.readFileSync('./ssl/key.pem'),
  cert: fs.readFileSync('./ssl/cert.pem'),
};

http.createServer(app).listen(3000, () => {
  console.log('HTTP server running at http://localhost:3000');
});