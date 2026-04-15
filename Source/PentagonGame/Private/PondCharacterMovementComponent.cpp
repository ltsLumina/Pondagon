// Copyright 2020 Dan Kestranek.


#include "PondCharacterMovementComponent.h"
#include "PondCharacter.h"

float UPondCharacterMovementComponent::GetMaxSpeed() const
{
	return BP_GetMaxSpeed();
}

bool UPondCharacterMovementComponent::CanAttemptJump() const
{
	return BP_CanAttemptJump();
}

float UPondCharacterMovementComponent::BP_GetMaxSpeed_Implementation() const
{
	checkf(true, TEXT("%s: should be implemented in script only!"), *FString(__FUNCTION__));
	return -1;
}

bool UPondCharacterMovementComponent::BP_CanAttemptJump_Implementation() const
{
	checkf(true, TEXT("%s: should be implemented in script only!"), *FString(__FUNCTION__));
	return false;
}

void UPondCharacterMovementComponent::UpdateFromCompressedFlags(uint8 Flags)
{
	Super::UpdateFromCompressedFlags(Flags);

	//The Flags parameter contains the compressed input flags that are stored in the saved move.
	//UpdateFromCompressed flags simply copies the flags from the saved move into the movement component.
	//It basically just resets the movement component to the state when the move was made so it can simulate from there.
	RequestToStartSprinting = (Flags & FSavedMove_Character::FLAG_Custom_0) != 0;

	RequestToStartADS = (Flags & FSavedMove_Character::FLAG_Custom_1) != 0;
}

FNetworkPredictionData_Client * UPondCharacterMovementComponent::GetPredictionData_Client() const
{
	check(PawnOwner != nullptr);

	if (!ClientPredictionData)
	{
		UPondCharacterMovementComponent* MutableThis = const_cast<UPondCharacterMovementComponent*>(this);

		MutableThis->ClientPredictionData = new FPondNetworkPredictionData_Client(*this);
		MutableThis->ClientPredictionData->MaxSmoothNetUpdateDist = 92.f;
		MutableThis->ClientPredictionData->NoSmoothNetUpdateDist = 140.f;
	}

	return ClientPredictionData;
}

void UPondCharacterMovementComponent::StartSprinting()
{
	RequestToStartSprinting = true;
}

void UPondCharacterMovementComponent::StopSprinting()
{
	RequestToStartSprinting = false;
}

void UPondCharacterMovementComponent::StartAimDownSights()
{
	RequestToStartADS = true;
}

void UPondCharacterMovementComponent::StopAimDownSights()
{
	RequestToStartADS = false;
}

void UPondCharacterMovementComponent::FPondSavedMove::Clear()
{
	Super::Clear();

	SavedRequestToStartSprinting = false;
	SavedRequestToStartADS = false;
}

uint8 UPondCharacterMovementComponent::FPondSavedMove::GetCompressedFlags() const
{
	uint8 Result = Super::GetCompressedFlags();

	if (SavedRequestToStartSprinting)
	{
		Result |= FLAG_Custom_0;
	}

	if (SavedRequestToStartADS)
	{
		Result |= FLAG_Custom_1;
	}

	return Result;
}

bool UPondCharacterMovementComponent::FPondSavedMove::CanCombineWith(const FSavedMovePtr & NewMove, ACharacter * Character, float MaxDelta) const
{
	//Set which moves can be combined together. This will depend on the bit flags that are used.
	if (SavedRequestToStartSprinting != ((FPondSavedMove*)&NewMove)->SavedRequestToStartSprinting)
	{
		return false;
	}

	if (SavedRequestToStartADS != ((FPondSavedMove*)&NewMove)->SavedRequestToStartADS)
	{
		return false;
	}

	return Super::CanCombineWith(NewMove, Character, MaxDelta);
}

void UPondCharacterMovementComponent::FPondSavedMove::SetMoveFor(ACharacter * Character, float InDeltaTime, FVector const & NewAccel, FNetworkPredictionData_Client_Character & ClientData)
{
	Super::SetMoveFor(Character, InDeltaTime, NewAccel, ClientData);

	UPondCharacterMovementComponent* CharacterMovement = Cast<UPondCharacterMovementComponent>(Character->GetCharacterMovement());
	if (CharacterMovement)
	{
		SavedRequestToStartSprinting = CharacterMovement->RequestToStartSprinting;
		SavedRequestToStartADS = CharacterMovement->RequestToStartADS;
	}
}

void UPondCharacterMovementComponent::FPondSavedMove::PrepMoveFor(ACharacter * Character)
{
	Super::PrepMoveFor(Character);

	UPondCharacterMovementComponent* CharacterMovement = Cast<UPondCharacterMovementComponent>(Character->GetCharacterMovement());
	if (CharacterMovement)
	{
	}
}

UPondCharacterMovementComponent::FPondNetworkPredictionData_Client::FPondNetworkPredictionData_Client(const UCharacterMovementComponent & ClientMovement)
	: Super(ClientMovement)
{
}

FSavedMovePtr UPondCharacterMovementComponent::FPondNetworkPredictionData_Client::AllocateNewMove()
{
	return FSavedMovePtr(new FPondSavedMove());
}