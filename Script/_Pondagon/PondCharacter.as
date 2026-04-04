UCLASS(Abstract)
class APondCharacter : ACharacter
{
	
}

namespace Pond
{
	UFUNCTION(BlueprintPure)
	APondCharacter GetPondCharacterBase(AActor Actor)
	{
		return Cast<APondCharacter>(Actor);
	}
}