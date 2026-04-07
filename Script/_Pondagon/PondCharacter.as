UCLASS(Abstract)
class AScriptPondCharacter : APondCharacter
{
	
}

namespace Pond
{
	UFUNCTION(BlueprintPure)
	AScriptPondCharacter GetPondCharacterBase(AActor Actor)
	{
		return Cast<AScriptPondCharacter>(Actor);
	}
}