UCLASS(Abstract)
class AScriptPondCharacter : ACharacter
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