namespace Math
{
	UFUNCTION(BlueprintPure)
	float ToMeters(float DistanceInCm)
	{
		return DistanceInCm / 100.0f;
	}

	UFUNCTION(BlueprintPure, Category = "Math", Meta = (CompactNodeTitle = "Round", Keywords = "round,decimal,places"))
	float RoundTo(float Value, int DecimalPlaces)
	{
		float Multiplier = Math::Pow(10.0f, DecimalPlaces);
		return Math::RoundToFloat(Value * Multiplier) / Multiplier;
	}
}

namespace AbilitySystem
{
	UFUNCTION(BlueprintPure)
	UAngelscriptAbilitySystemComponent GetAngelscriptAbilitySystemComponent(AActor Actor)
	{
		return Cast<UAngelscriptAbilitySystemComponent>(AbilitySystem::GetAbilitySystemComponent(Actor));
	}
}

namespace Asserts
{
	/**
	 * Throws a blueprint exception.
	 */
	UFUNCTION(Category = "Asserts", DisplayName = "Throw", Meta = (CompactNodeTitle = "throw", DevelopmentOnly))
	void Throw(FString Message)
	{
#if EDITOR
		Print(f"Blueprint Exception: {Message}\n{Exception::GetFormattedCallStack()}", 8.0f, FLinearColor::Red);
#endif
	}

	/**
	 * Throws a blueprint exception.
	 */
	UFUNCTION(Category = "Asserts", Meta = (CompactNodeTitle = "throw", DevelopmentOnly))
	void ThrowIf(bool Condition, FString Message)
	{
#if EDITOR
		if (Condition)
			Print(f"Blueprint Exception: {Message}\n{Exception::GetFormattedCallStack()}", 8.0f, FLinearColor::Red);
#endif
	}
}

namespace Editor
{
	/**
	 * Whether the game is currently running in the editor.
	 */
	UFUNCTION(BlueprintPure, Category = "Editor", Meta = (CompactNodeTitle = "Editor", Keywords = "editor,pc,platform"))
	bool IsEditor()
	{
#if EDITOR
		return true;
#else
		return false;
#endif
	}

	UFUNCTION(DisplayName = "Is Editor (branch)", Category = "Editor", Meta = (ExpandBoolAsExecs = "ReturnValue", Keywords = "editor,pc,platform"))
	bool IsEditor_Branch()
	{
#if EDITOR
		return true;
#else
		return false;
#endif
	}
}

namespace AdvancedSessions
{
	UFUNCTION(BlueprintPure)
    bool HasSteamConnection()
    {
        return AdvancedSessions::HasOnlineSubsystem(n"STEAM");
    }
}

namespace AController
{
	/**
	 * Returns whether this Controller is a local controller.
	 */
	UFUNCTION(DisplayName = "Is Local Controller (branch)", Category = "Pawn", Meta = (ExpandBoolAsExecs = "ReturnValue"))
	mixin bool IsLocalController(AController Controller)
	{
		return Controller.IsLocalController();
	}
}

/* -- ACTOR MIXINS -- */

mixin APawn AsPawn(AActor Actor)
{
	auto Result = Cast<APawn>(Actor);
	ThrowIf(Result == nullptr, f"Cast from {Actor.GetName()} to Pawn failed!");
	return Result;
}