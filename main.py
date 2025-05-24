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
        card = f"{suit}:{rank}"
        deck.append(card)

shuffled_deck = random.shuffle(deck)

beggining_on = True

while beggining_on: 
    number_players = int(input("how many playeres will play the game? (maxim 4)"))

    if number_players <=4:
        beggining_on = False

players = []

for player_num in range(number_players):
    player_hand = []
    for card in range(4):
        player_hand.append(deck.pop(random.randint(0, len(deck)-1)))
    players.append(player_hand)

table = []
table.append(deck.pop(0))

print("\nInitial table card:", table[0])


print(players)
    


for i, player in enumerate(players):
    print(f"player {i +1}")
    while True:
        first_card = int(input("what s the first card you want to see?(0-3)"))
        second_card = int(input("Whats the second card you want to see?"))
        if first_card <=3 and second_card <=3 and first_card != second_card:
            break
        print("Chose another cards")
     
    print(f"{player[first_card]} and {player[second_card]}")



















# for i, player in enumerate(players):
#     print(f"\nPlayer {i + 1}'s turn")
#     print("Your cards:")
#     for j, card in enumerate(player):
#         print(f"{j}: {card}")
    
#     while True:
#         try:
#             choice = int(input("Which card do you want to play? (0-3): "))
#             if 0 <= choice < len(player):
#                 break
#             print("Please enter a valid card number (0-3)")
#         except ValueError:
#             print("Please enter a number")
    
#     card = player.pop(choice)
#     table.append(card)
#     print(f"Player {i + 1} played: {card}")




