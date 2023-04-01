//---------------------------------------------------------------------------------------
//  FILE:    X2CustomCardManager.uc
//  AUTHOR:  Iridar  --  28/08/2022
//  PURPOSE: Alternative to the native X2CardManager.uc which stores decks and cards in
//	user profile settings, meaning that the decks are shared across all campaigns.
//	Custom Card Manager stores decks and cards inside individual save files, so they
//	will be campaign-specific.
//
//	The downside is that Custom Card Manager is a State Object that must be saved
//	in History, so it can be used to draw cards only when it's possible to work with
//	a NewGameState.
//	Also, Custom Card Manager must be created at the campaign start / when loading
//	a save that was created before adding this mod, example code below.
//
/*
static event InstallNewCampaign(XComGameState StartState)
{
	StartState.CreateNewStateObject(class'X2CustomCardManager');
}
static event OnLoadedSavedGame()
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(default.DLCIdentifier $ " Creating Custom Card Manager");
	NewGameState.CreateNewStateObject(class'X2CustomCardManager');
	`XCOMHISTORY.AddGameStateToHistory(NewGameState);
}
*/
//---------------------------------------------------------------------------------------
class X2CustomCardManager extends XComGameState_BaseObject;

struct CustomCardStruct
{
	var string	CardLabel;		// Label of this card, and its unique identifier.
	var int		UseCount;		// number of times this card has been MarkedAsUsed
	var float	InitialWeight;	// Initial weight of this card when it was added to the deck
};

struct CustomDeckStruct
{
	var name					DeckName;
	var array<CustomCardStruct>	Cards;
	var int						ShuffleCount; // Number of times this deck as been shuffled (partially or in full)
};

var private array<CustomDeckStruct> Decks;

// ------------------------------------------------------------------------------------------
// FUNCTIONS THAT ARE SAFE TO USE IN READ-ONLY SCENARIO

final function bool DoesDeckExist(name Deck)
{
	return Decks.Find('DeckName', Deck) != INDEX_NONE;
}

/// Returns all cards from the given deck in their current order
final function GetAllCardsInDeck(name Deck, out array<string> CardLabels)
{
	local int				DeckIndex;
	local CustomDeckStruct	CustomDeck;
	local CustomCardStruct	CustomCard;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return;

	CustomDeck = Decks[DeckIndex];

	`AMLOG("Found deck:" @ CustomDeck.DeckName @ "with this many cards:" @ CustomDeck.Cards.Length);

	foreach CustomDeck.Cards(CustomCard)
	{
		CardLabels.AddItem(CustomCard.CardLabel);
	}
}

/// Returns a list of all decks in the manager, by name
final function GetAllDeckNames(out array<name> DeckNames)
{
	local CustomDeckStruct CustomDeck;

	foreach Decks(CustomDeck)
	{
		DeckNames.AddItem(CustomDeck.DeckName);
	}
}


final function int GetCardUseCount(name Deck, string CardLabel)
{
	local int DeckIndex;
	local int CardIndex;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return INDEX_NONE;
	
	CardIndex = Decks[DeckIndex].Cards.Find('CardLabel', CardLabel);
	if (CardIndex == INDEX_NONE)
		return INDEX_NONE;

	return Decks[DeckIndex].Cards[CardIndex].UseCount;
}

final function int GetNumCardsInDeck(name Deck)
{
	local int DeckIndex;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return INDEX_NONE;

	return Decks[DeckIndex].Cards.Length;
}

// ------------------------------------------------------------------------------------------
// FUNCTIONS THAT CANNOT BE USED IN READ-ONLY SCENARIO

/// Adds the specified card to the specified deck
final function AddCardToDeck(name Deck, string CardLabel, optional float InitialWeight = 0)
{
	local CustomCardStruct			NewCard;
	local CustomDeckStruct			NewDeck;
	local int						DeckIndex;
	local int						CardIndex;
	local CustomCardStruct			CycleCard;

	NewCard.CardLabel = CardLabel;
	NewCard.InitialWeight = InitialWeight;

	DeckIndex = Decks.Find('DeckName', Deck);

	`AMLOG("Deck:" @ Deck @ "Card:" @ CardLabel @ "InitialWeight:" @ InitialWeight);

	// If deck doesn't exist yet - create it.
	if (DeckIndex == INDEX_NONE)
	{
		NewDeck.DeckName = Deck;
		NewDeck.Cards.AddItem(NewCard);
		Decks.AddItem(NewDeck);

		`AMLOG("Deck doesn't exist, creating.");

		return;
	}

	// Don't do anything if the card already exists
	if (Decks[DeckIndex].Cards.Find('CardLabel', CardLabel) != INDEX_NONE)
	{
		`AMLOG("Card is already in the deck, exiting.");
		return;
	}

	PrintDeck(Deck);

	// Go through the deck, top to bottom
	for (CardIndex = 0; CardIndex < Decks[DeckIndex].Cards.Length; CardIndex++)
	{
		CycleCard = Decks[DeckIndex].Cards[CardIndex];

		if (CycleCard.UseCount > 0)
		{
			`AMLOG("Insering Card:" @ CardLabel @ "into position:" @ CardIndex @ "because the cycle card was already used.");
			Decks[DeckIndex].Cards.InsertItem(CardIndex, NewCard);
			break;
		}
		else if (CycleCard.InitialWeight < NewCard.InitialWeight)
		{
			`AMLOG("Insering Card:" @ CardLabel @ "into position:" @ CardIndex @ "because the cycle card has lower weight.");
			Decks[DeckIndex].Cards.InsertItem(CardIndex, NewCard);
			break;
		}
		else if (CardIndex == Decks[DeckIndex].Cards.Length - 1)
		{
			`AMLOG("Adding Card:" @ CardLabel @ "to the end of deck");
			Decks[DeckIndex].Cards.AddItem(NewCard);
			break;
		}
	}

	PrintDeck(Deck);

	// A deck is eligible for a shuffle when all cards have the same number of uses.
	if (DoesDeckNeedShuffle(Deck))
	{
		ShuffleDeck(Deck);
	}
}

final function PrintDeck(name Deck)
{
	local int	DeckIndex;
	local int	CardIndex;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return;

	`AMLOG("------------------START DECK:" @ Deck @ "-------------------------------------------");
	for (CardIndex = 0; CardIndex <  Decks[DeckIndex].Cards.Length; CardIndex++)
	{
		`AMLOG(CardIndex @ Decks[DeckIndex].Cards[CardIndex].CardLabel @ Decks[DeckIndex].Cards[CardIndex].InitialWeight @ Decks[DeckIndex].Cards[CardIndex].UseCount);
	}
	`AMLOG("------------------END DECK:" @ Deck @ "-------------------------------------------");
}

// Replace card label of a card with a different label, preserving the UseCount.
final function UpdateCardLabel(name Deck, string OldLabel, string NewLabel)
{
	local int	DeckIndex;
	local int	CardIndex;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return;
	
	CardIndex = Decks[DeckIndex].Cards.Find('CardLabel', OldLabel);
	if (CardIndex == INDEX_NONE)
		return;

	Decks[DeckIndex].Cards[CardIndex].CardLabel = NewLabel;

	`AMLOG("Deck:" @ Deck @ "OldLabel:" @ OldLabel @ "NewLabel:"@ NewLabel);
}

/// Removes the specified card from the specified deck
final function RemoveCardFromDeck(name Deck, string CardLabel)
{
	local int	DeckIndex;
	local int	CardIndex;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return;
	
	CardIndex = Decks[DeckIndex].Cards.Find('CardLabel', CardLabel);
	if (CardIndex == INDEX_NONE)
		return;

	Decks[DeckIndex].Cards.Remove(CardIndex, 1);
}

/// Prototype for validation delegates to SelectNextCardFromDeck
delegate bool CardValidateDelegate(string CardLabel, Object ValidationData);

/// Selects the next card from the specified deck. If the optional validation function is provided,
/// will pick the next card that passes the validation check. If MarkAsUsed is set, will automatically
/// remove the card from the deck and place it at the bottom of the deck. Validation data is a user supplied datum
/// to make passing state into the validation delegate cleaner and easier.
final function bool SelectNextCardFromDeck(name Deck, 
											out string CardLabel,
											optional delegate<CardValidateDelegate> Validator = none, 
											optional Object ValidationData, 
											optional bool MarkAsUsed = true)
{
	local int				DeckIndex;
	local CustomDeckStruct	CustomDeck;
	local CustomCardStruct	CustomCard;
	
	CardLabel = "";

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return false;

	CustomDeck = Decks[DeckIndex];

	foreach CustomDeck.Cards(CustomCard)
	{
		if (Validator != none)
		{
			if (!Validator(CustomCard.CardLabel, ValidationData))
				continue;
		}

		CardLabel = CustomCard.CardLabel;
		if (MarkAsUsed)
		{
			MarkCardUsed(Deck, CardLabel);
		}
		return true;
	}

	return false;
}

/// Marks the given card as "used" and returns it to the bottom of the deck.
/// Does nothing if the card does not exist in the deck.
final function MarkCardUsed(name Deck, string CardLabel)
{
	local int				DeckIndex;
	local int				CardIndex;
	local CustomCardStruct	CustomCard;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return;
	
	CardIndex = Decks[DeckIndex].Cards.Find('CardLabel', CardLabel);
	if (CardIndex == INDEX_NONE)
		return;

	CustomCard = Decks[DeckIndex].Cards[CardIndex];

	Decks[DeckIndex].Cards.Remove(CardIndex, 1);

	CustomCard.UseCount++;

	Decks[DeckIndex].Cards.AddItem(CustomCard);

	if (DoesDeckNeedShuffle(Deck))
	{
		`AMLOG("Shuffling deck:" @ Deck);
		ShuffleDeck(Deck);
	}
}

private function bool DoesDeckNeedShuffle(name Deck)
{
	local int						DeckIndex;
	local int						CardIndex;
	local array<CustomCardStruct>	CustomCards;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return false;
	
	CustomCards = Decks[DeckIndex].Cards;
	if (CustomCards.Length <= 1)
		return false;

	for (CardIndex = 1; CardIndex < CustomCards.Length; CardIndex++)
	{
		if (CustomCards[CardIndex - 1].UseCount != CustomCards[CardIndex].UseCount)
		{
			return false;
		}
	}

	return true;
}

final function ShuffleDeck(name Deck)
{
	local int DeckIndex;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return;

	`AMLOG("Shuffling deck:" @ Deck);

	ShuffleDeckIgnoreWeight(Deck);

	Decks[DeckIndex].Cards.Sort(SortCardsByWeight);

	PrintDeck(Deck);
}

private final function int SortCardsByWeight(CustomCardStruct CardA, CustomCardStruct CardB)
{
	if (CardA.InitialWeight > CardB.InitialWeight)
	{
		return 1;
	}
	else if (CardA.InitialWeight < CardB.InitialWeight)
	{
		return -1;
	}
	return 0;
}

final function ShuffleDeckIgnoreWeight(name Deck)
{
	local int						DeckIndex;
	local CustomCardStruct			CustomCard;
	local array<CustomCardStruct>	CustomCards;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return;

	CustomCards = Decks[DeckIndex].Cards;
	Decks[DeckIndex].Cards.Length = 0;
	foreach CustomCards(CustomCard)
	{
		// `SYNC_RAND(x) - returns a random `int` value from [0; x) range.
		Decks[DeckIndex].Cards.InsertItem(`SYNC_RAND(Decks[DeckIndex].Cards.Length), CustomCard);
	}

	Decks[DeckIndex].ShuffleCount++;
}

final function RemoveDeck(name Deck)
{
	local int DeckIndex;

	DeckIndex = Decks.Find('DeckName', Deck);
	if (DeckIndex == INDEX_NONE)
		return;

	Decks.Remove(DeckIndex, 1);
}

// ------------------------------------------------------------------------------------------
// GETTERS

/// Get the custom card manager. You MUST call ModifyStateObject with a NewGameState on it, or use it as read-only.
static final function X2CustomCardManager GetCustomCardManager(optional XComGameState GameState)
{
	local X2CustomCardManager StateObject;

	if (GameState != none)
	{
		foreach GameState.IterateByClassType(class'X2CustomCardManager', StateObject)
		{
			return StateObject;
		}
	}

	return X2CustomCardManager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'X2CustomCardManager', false));
}

/// Get the custom card manager and use it for any purpose.
static final function X2CustomCardManager GetAndPrepCustomCardManager(XComGameState NewGameState)
{
	local X2CustomCardManager StateObject;

	foreach NewGameState.IterateByClassType(class'X2CustomCardManager', StateObject)
	{
		return StateObject;
	}
	
	StateObject = X2CustomCardManager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'X2CustomCardManager', true));
	if (StateObject == none)
	{
		return X2CustomCardManager(NewGameState.CreateNewStateObject(class'X2CustomCardManager'));
	}

	StateObject = X2CustomCardManager(NewGameState.ModifyStateObject(StateObject.Class, StateObject.ObjectID));

	return StateObject;
}