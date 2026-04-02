struct FDeathContext
{
	UPROPERTY(BlueprintReadOnly)
	AController InstigatedBy;

	UPROPERTY(BlueprintReadOnly)
	AActor DamageCauser;

	/**
	 * May be null.
	 */
	UPROPERTY(BlueprintReadOnly)
	UWeaponInstance WeaponUsed;

	/**
	 * May be null.
	 */
	UPROPERTY(BlueprintReadOnly)
	UPondAbility AbilityUsed;

	FDeathContext(AController InInstigatedBy, AActor InDamageCauser, UWeaponInstance InWeaponUsed = nullptr, UPondAbility InAbilityUsed = nullptr)
	{
		InstigatedBy = InInstigatedBy;
		DamageCauser = InDamageCauser;
		WeaponUsed = InWeaponUsed;
		AbilityUsed = InAbilityUsed;
	}
}

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