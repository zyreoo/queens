import random

# 1. i need to see how many players i will have n my game. 
# 2. i need to give each player 4 cards i think i will have an 12 max capacity, or maybe 18 i will think about it, but for now i will only be a 4 game
# 3. i will shuffle 2 packs of cards, because i will need cards to give. 

suits = ["♣️", "♠️", "♥️", "♦️"]
ranks = ["2", "3","4", "5", "6", "7","8", "9", "10", "J", "Q", "K", "A"]

values = {"2": 2, "3": 3, "4": 4, "5":5, "6":6, 
          "7":7, "8":8, "9":9, "10":10, 
          "J":11, "K":12, "A":13, "Q": 14}

score_values = {"2": 2, "3": 3, "4": 4, "5":5, "6":6, 
          "7":7, "8":8, "9":9, "10":10, 
          "J":10, "K":10, "A":1, "Q":0}


deck = []

for _ in range (2):
    for suit in suits:
        for rank in ranks:
            card  = f"{suit}:{rank}"
            deck.append(card)


shuffled_deck = deck.copy()
random.shuffle(shuffled_deck)



# begging of the game

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
used_deck = []

print("\nInitial table card:", table[0])


for i, player in enumerate(players):
    print(f"player {i +1}")

    print(" ".join(f"{j} *_*" for j in range(len(player))))
    while True:
        first_card = int(input("what s the first card you want to see?(0-3)"))
        second_card = int(input("Whats the second card you want to see?"))
        if first_card <=3 and second_card <=3 and first_card != second_card:
            break
        print("Chose another cards")
     
    print(f"{player[first_card]} and {player[second_card]}")


game_on = True
end_after_round = False



def get_card_value(card, values_dict):
    _, rank = card.split(":")
    return values_dict[rank]


def calculate_score(hand, values):
    return sum(get_card_value(card, values) for card in hand)


# the actually game


while game_on:
    for i, player in enumerate(players):
        print(table)
        print(f"Player {i +1} turn")

        player.append(shuffled_deck.pop(0))

        print(' '.join(f"{j} *_*" for j in range (len(player))))

        response = int(input("What card would you like to play?"))
        
        played_card = player.pop(response)
        table.append(played_card)
        print(f"player {i+1} played {played_card}")


        while len(table) >1:
            used_deck.append(table.pop(0))

        for k, card in enumerate (player):
            if get_card_value(card, values) == get_card_value(table[0], values):
                response = input("would you like to put down ur card? y or n")
                if response == "y":
                    table.append(player.pop(k))

        if get_card_value(played_card, values) == 11:
            print("You played a jack, you can exchange with another player")
            choice = input("would you like to exchange?(y/n)")

            if choice.lower() == "y":

                for idx, p in enumerate(players):
                    if idx != 1:
                        print(f"Player {idx +1 }: {len(p)} cards")

                target_player = int(input("From which player would you like to exchange?"))-1
                if target_player == i or target_player > len(players):
                    print("Invalid choose")
                else:
                    print("Your hand:")

                    for idx,card in enumerate (player):
                        print(f"{idx}:{card}")
                    your_card_index = int(input("What card from YOU would you like to trade?"))

                    print("their hand")

                    for idx,card  in enumerate(players[target_player]):
                        print(f"{idx}:{card}")
                    their_card_index = int(input("Which card from their pack would you like to trade"))    
                    
                    player[your_card_index], players[target_player][their_card_index] = (players[target_player][their_card_index],player[your_card_index])

                    print(player)
                    print(players[target_player])

            
        if get_card_value(played_card, values) == 12:
            print("You have just played a King. Now you can choose to see one of ur cards")

            choice = input("Would you like to see one of ur cards? (y/n)")

            if choice == "y":

                for idx, card in enumerate (player):
                    print(f"{idx}:*_*")

                show_card = int(input("Which card would you like to choose?"))

                print(player[show_card])


        if get_card_value(played_card, values) == 14:
            print("Ahh, you played a Queen.. this queen will go to the next person")

            next_player_index = (i+1) % len(players)
            players[next_player_index].append(played_card)
        
        queens_response = input("Do you say queens?(y/n)")
        if queens_response == "y":
            end_after_round = True

    if end_after_round:
        game_on = False
        for i, player in enumerate (players):
            score = calculate_score(player, values)
            print(f"Player {i+1}: {score} points")
            
    
    