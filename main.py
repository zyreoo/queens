import random

# 1. i need to see how many players i will have n my game. 
# 2. i need to give each player 4 cards i think i will have an 12 max capacity, or maybe 18 i will think about it, but for now i will only be a 4 game
# 3. i will shuffle 2 packs of cards, because i will need cards to give. 

suits = ["♣️", "♠️", "♥️", "♦️","♣️", "♠️", "♥️", "♦️"]
ranks = ["2", "3","4", "5", "6", "7","8", "9", "10", "J", "Q", "K", "A","2", "3","4", "5", "6", "7","8", "9", "10", "J", "Q", "K", "A"]

values = {"2": 2, "3": 3, "4": 4, "5":5, "6":6, 
          "7":7, "8":8, "9":9, "10":10, 
          "J":10, "K":10, "A":1, "Q": 0}


deck = []

for suit in suits:
    for rank in ranks:
        card = {"suit": suit, "rank":rank, "value": values[rank]}
        deck.append(card)

print(deck)








